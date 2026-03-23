import 'package:beangle_app/common/common_color.dart';
import 'package:beangle_app/worker/model/cycle_station.dart';
import 'package:beangle_app/worker/view/worker_theme.dart';
import 'package:flutter/material.dart';

class CycleStationMarker extends StatelessWidget {
  const CycleStationMarker({
    super.key,
    required this.station,
    required this.currentTimeLabel,
    required this.nextRelocationLabel,
    required this.currentCount,
    this.cumulativeInflow,
    this.cumulativeOutflow,
    this.preInflow,
    this.preOutflow,
  });

  final CycleStation station;
  final String currentTimeLabel;
  final String nextRelocationLabel;
  final int currentCount;
  final double? cumulativeInflow;
  final double? cumulativeOutflow;
  final double? preInflow;
  final double? preOutflow;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final int? inflowValue =
            cumulativeInflow == null ? null : cumulativeInflow!.round();
        final int? outflowValue =
            cumulativeOutflow == null ? null : cumulativeOutflow!.round();
        final int? netFlowValue =
            (inflowValue != null && outflowValue != null)
                ? inflowValue - outflowValue
                : null;
        final int? actionDelta =
            netFlowValue == null ? null : netFlowValue - currentCount;
        final int? preInflowValue =
            preInflow == null ? null : preInflow!.round();
        final int? preOutflowValue =
            preOutflow == null ? null : preOutflow!.round();
        final int? preNetValue =
            (preInflowValue != null && preOutflowValue != null)
                ? preInflowValue - preOutflowValue
                : null;
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final panelColor = CommonColor.panelColor(isDarkTheme);
        final accentColor = CommonColor.cardAccent();
        final primaryTextColor = CommonColor.primaryTextColor(isDarkTheme);
        final labelTextColor = CommonColor.labelTextColor(isDarkTheme);

        showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return Theme(
              data: Theme.of(context).copyWith(
                brightness: isDarkTheme ? Brightness.dark : Brightness.light,
                dialogTheme: DialogThemeData(backgroundColor: panelColor),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              child: AlertDialog(
                backgroundColor: panelColor,
                title: Text(
                  station.name,
                  style: TextStyle(color: primaryTextColor),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.pedal_bike,
                            color: accentColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DialogInfoLine(
                                label: '현재시간',
                                value: currentTimeLabel,
                                labelColor: labelTextColor,
                                valueColor: accentColor,
                              ),
                              _DialogInfoLine(
                                label: '재배치 시간',
                                value: nextRelocationLabel,
                                labelColor: labelTextColor,
                                valueColor: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _DialogInfoLine(
                      label: '현재 댓수',
                      value: '$currentCount대',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    _DialogInfoLine(
                      label: '재배치 시 예측 댓수',
                      value: preNetValue == null
                          ? '데이터 없음'
                          : '${preNetValue >= 0 ? '+' : ''}$preNetValue대 (${(currentCount+preNetValue)}대)',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    _DialogInfoLine(
                      label: '예측 누적 유입량',
                      value:
                          inflowValue == null ? '데이터 없음' : '$inflowValue대',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    _DialogInfoLine(
                      label: '예측 누적 유출량',
                      value:
                          outflowValue == null ? '데이터 없음' : '$outflowValue대',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    _DialogInfoLine(
                      label: '예측 누적 순증감',
                      value: netFlowValue == null
                          ? '데이터 없음'
                          : '${netFlowValue >= 0 ? '+' : ''}$netFlowValue대',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    _DialogInfoLine(
                      label: '작업 안내',
                      value: actionDelta == null
                          ? '데이터 없음'
                          : actionDelta == 0
                              ? '현재 상태 유지'
                              : actionDelta > 0
                                  ? '추가 배치 ${actionDelta}대'
                                  : '회수 ${actionDelta.abs()}대 (다른 곳 이동)',
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: workerThemeColor, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${station.name}: ${station.parkingCount}대/ ${station.rackCount}대',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: workerThemeColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Icon(Icons.pedal_bike, color: workerThemeColor, size: 20),
        ],
      ),
    );
  }
}

class _DialogInfoLine extends StatelessWidget {
  const _DialogInfoLine({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: labelColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
