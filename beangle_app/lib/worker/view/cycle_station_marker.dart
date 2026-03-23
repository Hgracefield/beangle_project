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
    this.neededCount,
  });
  
  final CycleStation station;
  final String currentTimeLabel;
  final String nextRelocationLabel;
  final int currentCount;
  final int? neededCount;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) {
            final neededLabel = neededCount == null
                ? '데이터 없음'
                : '${neededCount!}대';
            return AlertDialog(
              title: Text(station.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 시간 : $currentTimeLabel'),
                  Text('다음 재배치 시간 : $nextRelocationLabel'),
                  Text('현재 댓수 : ${currentCount}대'),
                  Text('필요한 댓수 : $neededLabel'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
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
          const Icon(
            Icons.pedal_bike,
            color: workerThemeColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}
