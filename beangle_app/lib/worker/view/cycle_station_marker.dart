import 'package:beangle_app/worker/model/cycle_station.dart';
import 'package:flutter/material.dart';

class CycleStationMarker extends StatelessWidget {
  const CycleStationMarker({super.key, required this.station});
  
  final CycleStation station;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF2D8C6A), width: 1.5),
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
              color: Color(0xFF1D6E52),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Icon(
          Icons.pedal_bike,
          color: Color(0xFF2D8C6A),
          size: 20,
        ),
      ],
    );
  }
}