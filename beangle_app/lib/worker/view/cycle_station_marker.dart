import 'package:beangle_app/common/common_color.dart';
import 'package:beangle_app/worker/model/cycle_station.dart';
import 'package:beangle_app/worker/model/work_api.dart';
import 'package:beangle_app/worker/model/work_record.dart';
import 'package:beangle_app/worker/view/worker_theme.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

class CycleStationMarker extends StatelessWidget {
  const CycleStationMarker({
    super.key,
    required this.station,
    required this.isCompleted,
    required this.currentTime,
    required this.nextRelocationTime,
    required this.currentTimeLabel,
    required this.nextRelocationLabel,
    required this.currentCount,
    this.onWorkSubmitted,
    this.cumulativeInflow,
    this.cumulativeOutflow,
    this.preInflow,
    this.preOutflow,
  });

  final CycleStation station;
  final bool isCompleted;
  final DateTime currentTime;
  final DateTime nextRelocationTime;
  final String currentTimeLabel;
  final String nextRelocationLabel;
  final int currentCount;
  final Future<void> Function()? onWorkSubmitted;
  final double? cumulativeInflow;
  final double? cumulativeOutflow;
  final double? preInflow;
  final double? preOutflow;

  static final WorkApi _workApi = WorkApi();
  static final GetStorage _storage = GetStorage();

  bool _isSameSlot(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour;
  }

  Future<void> _handleSubmitWork({
    required BuildContext context,
    required bool isActionWindowActive,
    required DateTime targetTime,
    required int workCount,
  }) async {
    if (!isActionWindowActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재배치 시간이 아닙니다')),
      );
      return;
    }

    if (workCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송할 작업 수량이 없습니다')),
      );
      return;
    }

    final int? workerId =
        int.tryParse(_storage.read('worker_id')?.toString() ?? '');
    if (workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업자 로그인 정보가 없습니다')),
      );
      return;
    }

    final int? stationId =
        int.tryParse(station.id.replaceFirst('ST-', ''));
    if (stationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스테이션 번호를 확인할 수 없습니다')),
      );
      return;
    }

    try {
      final List<WorkRecord> works = await _workApi.fetchWorks();
      final bool alreadyWorked = works.any((WorkRecord item) {
        return item.stationId == stationId && _isSameSlot(item.time, targetTime);
      });

      if (alreadyWorked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('같은 시간대에 이미 해당 스테이션 작업이 등록되었습니다'),
          ),
        );
        return;
      }

      final WorkRecord payload = WorkRecord(
        workerId: workerId,
        stationId: stationId,
        count: workCount,
        time: targetTime,
      );

      final int result = await _workApi.insertWork(payload);
      if (result != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('같은 시간대에 이미 해당 스테이션 작업이 등록되었습니다'),
          ),
        );
        return;
      }

      await onWorkSubmitted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${station.name} 작업 내역이 저장되었습니다')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 내역 저장에 실패했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color markerBorderColor =
        isCompleted ? const Color(0xFF2F6BFF) : workerThemeColor;

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
        final int? preInflowValue =
            preInflow == null ? null : preInflow!.round();
        final int? preOutflowValue =
            preOutflow == null ? null : preOutflow!.round();
        final int? preNetValue =
            (preInflowValue != null && preOutflowValue != null)
                ? preInflowValue - preOutflowValue
                : null;
        final int? predictedCountAtRelocation =
            preNetValue == null ? null : currentCount + preNetValue;
        final int? actionDelta =
            (netFlowValue != null && preNetValue != null)
                ? netFlowValue - currentCount + preNetValue
                : null;
        final int? limitedRecoveryCount =
            (actionDelta != null &&
                    actionDelta < 0 &&
                    predictedCountAtRelocation != null &&
                    actionDelta.abs() > predictedCountAtRelocation)
                ? (predictedCountAtRelocation - station.rackCount)
                    .clamp(0, predictedCountAtRelocation)
                    .toInt()
                : null;
        final String actionGuide =
            actionDelta == null
                ? '데이터 없음'
                : actionDelta == 0
                    ? '현재 상태 유지'
                    : actionDelta > 0
                        ? '추가 배치 ${actionDelta}대'
                        : limitedRecoveryCount != null
                            ? limitedRecoveryCount == 0
                                ? '회수 없음 (예측 댓수가 거치대 수 이하)'
                                : '회수 ${limitedRecoveryCount}대 (거치대 수 ${station.rackCount}대만 남김)'
                            : '회수 ${actionDelta.abs()}대 (다른 곳 이동)';
        final int submissionCount =
            actionDelta == null
                ? 0
                : actionDelta > 0
                    ? actionDelta
                    : limitedRecoveryCount ?? actionDelta.abs();
        final DateTime activationStart = nextRelocationTime.subtract(
          const Duration(hours: 5),
        );
        final DateTime activationEnd = nextRelocationTime.add(
          const Duration(hours: 5),
        );
        final bool isActionWindowActive =
            !currentTime.isBefore(activationStart) &&
            !currentTime.isAfter(activationEnd);
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
                      label: '재배치 직전 예상 대수',
                      value: preNetValue == null
                          ? '데이터 없음'
                          : '$predictedCountAtRelocation대 (${preNetValue >= 0 ? '+' : ''}$preNetValue대)',
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
                      value: actionGuide,
                      labelColor: labelTextColor,
                      valueColor: primaryTextColor,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _handleSubmitWork(
                            context: context,
                            isActionWindowActive:  isActionWindowActive,
                            targetTime: nextRelocationTime,
                            workCount: submissionCount,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isActionWindowActive
                                  ? accentColor
                                  : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(
                          isActionWindowActive
                              ? Icons.assignment_turned_in
                              : Icons.lock_clock,
                        ),
                        label: Text(
                          isActionWindowActive ? '작업 내역 전송' : '작업 내역 전송',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '재배치 시간 기준 1시간 전부터 1시간 후까지만 활성화됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: labelTextColor,
                      ),
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
              border: Border.all(color: markerBorderColor, width: 1.5),
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
          Icon(Icons.pedal_bike, color: markerBorderColor, size: 20),
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
            width: 120,
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
