from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    src = root / "assets" / "data" / "station_hourly_predictions.json"
    out = root / "python" / "generated" / "station_prediction_hourly.sql"
    out.parent.mkdir(parents=True, exist_ok=True)

    data = json.loads(src.read_text(encoding="utf-8"))

    lines: list[str] = [
        "CREATE TABLE IF NOT EXISTS station_prediction_hourly (",
        "  station_id VARCHAR(20) NOT NULL,",
        "  station_number VARCHAR(20) NOT NULL,",
        "  station_name VARCHAR(50) NOT NULL,",
        "  prediction_month TINYINT NOT NULL,",
        "  prediction_weekday TINYINT NOT NULL,",
        "  base_hour TINYINT NOT NULL,",
        "  offset_hour TINYINT NOT NULL,",
        "  predicted_inflow DECIMAL(10,3) NOT NULL,",
        "  predicted_outflow DECIMAL(10,3) NOT NULL,",
        "  predicted_net_flow DECIMAL(10,3) NOT NULL,",
        "  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,",
        "  PRIMARY KEY (station_id, prediction_month, prediction_weekday, base_hour, offset_hour)",
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
        "",
        "INSERT INTO station_prediction_hourly (",
        "  station_id, station_number, station_name, prediction_month, prediction_weekday,",
        "  base_hour, offset_hour, predicted_inflow, predicted_outflow, predicted_net_flow",
        ") VALUES",
    ]

    values: list[str] = []

    for station_id, station_payload in data.items():
        meta = station_payload["meta"]
        station_name = str(meta["name"]).replace("'", "''")
        station_number = str(meta["number"]).replace("'", "''")
        slots = station_payload["slots"]

        for month, month_payload in slots.items():
            for weekday, weekday_payload in month_payload.items():
                for base_hour, hour_payload in weekday_payload.items():
                    offsets = hour_payload.get("offsets", {})
                    for offset_hour, offset_payload in offsets.items():
                        values.append(
                            "("
                            f"'{station_id}', "
                            f"'{station_number}', "
                            f"'{station_name}', "
                            f"{int(month)}, "
                            f"{int(weekday)}, "
                            f"{int(base_hour)}, "
                            f"{int(offset_hour)}, "
                            f"{float(offset_payload['inflow']):.3f}, "
                            f"{float(offset_payload['outflow']):.3f}, "
                            f"{float(offset_payload['net_flow']):.3f}"
                            ")"
                        )

    if values:
        lines.append(",\n".join(values) + ";")
    else:
        lines.append("('','','',0,0,0,0,0,0,0);")

    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
