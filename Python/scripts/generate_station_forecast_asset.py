from __future__ import annotations

import ast
import json
from pathlib import Path

import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline


OUTPUT_STATIONS = {
    "ST-481": {"name": "상현", "number": "933"},
    "ST-2425": {"name": "다원", "number": "4652"},
    "ST-1331": {"name": "찬솔", "number": "956"},
    "ST-454": {"name": "신영", "number": "906"},
    "ST-453": {"name": "혜전", "number": "905"},
}
TRAIN_STATIONS = ["ST-481", "ST-2425", "ST-1331", "ST-454", "ST-453", "ST-2264"]
BASE_FEATURE_COLS = [
    "weekday_0",
    "weekday_1",
    "weekday_2",
    "weekday_3",
    "weekday_4",
    "weekday_5",
    "weekday_6",
    "is_weekend",
    "holiday_flag",
    "온도",
    "습도",
    "강수량",
    "불쾌지수",
    "snow_flag",
    "hour_sin",
    "hour_cos",
]


def load_best_model_params(h5_path: Path) -> dict[str, dict]:
    best_df = pd.read_hdf(h5_path, "/summary/final_best_by_target")
    best_params: dict[str, dict] = {}

    for target in ["inflow", "outflow"]:
        row = best_df.loc[best_df["target"] == target].iloc[0]
        if row["model"] != "HGB":
            raise ValueError(f"Unsupported best model for {target}: {row['model']}")
        best_params[target] = ast.literal_eval(row["best_params"])

    return best_params


def make_design_matrix(df: pd.DataFrame, train_columns: list[str] | None = None) -> tuple[pd.DataFrame, list[str]]:
    base = df[BASE_FEATURE_COLS + ["station_id"]].copy()
    design = pd.get_dummies(base, columns=["station_id"])

    if train_columns is not None:
        design = design.reindex(columns=train_columns, fill_value=0)
        return design, train_columns

    columns = design.columns.tolist()
    return design, columns


def load_train_test_frames(h5_path: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    train_parts = []
    test_parts = []

    for station_id in TRAIN_STATIONS:
        train_parts.append(pd.read_hdf(h5_path, f"/station_model_2024/{station_id}"))
        test_parts.append(pd.read_hdf(h5_path, f"/station_model_2025/{station_id}"))

    train_df = pd.concat(train_parts, ignore_index=True).sort_values("timestamp").reset_index(drop=True)
    test_df = pd.concat(test_parts, ignore_index=True).sort_values("timestamp").reset_index(drop=True)
    return train_df, test_df


def train_target_model(
    train_df: pd.DataFrame,
    feature_columns: list[str],
    target: str,
    params: dict,
) -> Pipeline:
    X_train, _ = make_design_matrix(train_df, feature_columns)
    y_train = train_df[target]
    sample_weight = train_df["sample_weight"].values

    model = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("hgb", HistGradientBoostingRegressor(random_state=42, **{
                key.replace("histgradientboostingregressor__", ""): value
                for key, value in params.items()
            })),
        ]
    )
    model.fit(X_train, y_train, hgb__sample_weight=sample_weight)
    return model


def build_prediction_frame(h5_path: Path) -> pd.DataFrame:
    best_params = load_best_model_params(h5_path)
    train_df, test_df = load_train_test_frames(h5_path)
    _, feature_columns = make_design_matrix(train_df)

    inflow_model = train_target_model(train_df, feature_columns, "inflow", best_params["inflow"])
    outflow_model = train_target_model(train_df, feature_columns, "outflow", best_params["outflow"])

    X_test, _ = make_design_matrix(test_df, feature_columns)
    predicted = test_df.copy()
    predicted["pred_inflow"] = inflow_model.predict(X_test).clip(min=0)
    predicted["pred_outflow"] = outflow_model.predict(X_test).clip(min=0)
    predicted["pred_net_flow"] = predicted["pred_inflow"] - predicted["pred_outflow"]
    return predicted


def build_lookup_table(df: pd.DataFrame) -> dict[tuple[int, int, int], dict[str, float]]:
    grouped = (
        df.groupby(["month", "weekday", "시간대"])[["pred_inflow", "pred_outflow", "pred_net_flow"]]
        .mean()
        .reset_index()
    )

    lookup: dict[tuple[int, int, int], dict[str, float]] = {}
    for row in grouped.itertuples(index=False):
        lookup[(int(row.month), int(row.weekday), int(getattr(row, "시간대")))] = {
            "inflow": round(float(row.pred_inflow), 3),
            "outflow": round(float(row.pred_outflow), 3),
            "net_flow": round(float(row.pred_net_flow), 3),
        }
    return lookup


def build_station_asset(lookup: dict[tuple[int, int, int], dict[str, float]]) -> dict[str, dict]:
    station_result: dict[str, dict] = {}

    for month in range(1, 13):
        month_map = station_result.setdefault(str(month), {})
        for weekday in range(0, 7):
            weekday_map = month_map.setdefault(str(weekday), {})
            for hour in range(0, 24):
                base = dict(
                    lookup.get(
                        (month, weekday, hour),
                        {"inflow": 0.0, "outflow": 0.0, "net_flow": 0.0},
                    )
                )
                offsets: dict[str, dict[str, float]] = {}

                for offset in range(1, 9):
                    cumulative_inflow = 0.0
                    cumulative_outflow = 0.0
                    cumulative_net_flow = 0.0

                    for step in range(1, offset + 1):
                        step_target = pd.Timestamp(year=2025, month=month, day=1, hour=hour) + pd.Timedelta(hours=step)
                        step_month = int(step_target.month)
                        step_weekday = int((weekday + ((hour + step) // 24)) % 7)
                        step_hour = int(step_target.hour)
                        step_data = lookup.get(
                            (step_month, step_weekday, step_hour),
                            {"inflow": 0.0, "outflow": 0.0, "net_flow": 0.0},
                        )
                        cumulative_inflow += step_data["inflow"]
                        cumulative_outflow += step_data["outflow"]
                        cumulative_net_flow += step_data["net_flow"]

                    offsets[str(offset)] = {
                        "inflow": round(cumulative_inflow, 3),
                        "outflow": round(cumulative_outflow, 3),
                        "net_flow": round(cumulative_net_flow, 3),
                    }

                base["offsets"] = offsets
                weekday_map[str(hour)] = base

    return station_result


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    src = root / "python" / "Data" / "real_final_outputs.h5"
    out = root / "assets" / "data" / "station_hourly_predictions.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    prediction_frame = build_prediction_frame(src)
    result: dict[str, dict] = {}

    for station_id, station_meta in OUTPUT_STATIONS.items():
      station_df = prediction_frame.loc[prediction_frame["station_id"] == station_id].copy()
      lookup = build_lookup_table(station_df)
      result[station_id] = {
          "meta": station_meta,
          "source": "trained_model_prediction",
          "slots": build_station_asset(lookup),
      }

    out.write_text(
        json.dumps(result, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(out)


if __name__ == "__main__":
    main()
