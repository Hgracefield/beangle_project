import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:flutter/material.dart';

class ReservationCardWidget extends StatelessWidget {
  const ReservationCardWidget({super.key, required this.reservation});

  final ReservationInfo reservation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              children: [
                _ReservationRow(
                  label: '예약 일자',
                  value: reservation.time.year.toString() + '-' + reservation.time.month.toString() + '-' + reservation.time.day.toString(),
                ),
                const SizedBox(height: 16),
                _ReservationRow(label: '예약 시간', value: reservation.time.hour.toString()),
                const SizedBox(height: 16),
                _ReservationRow(label: '대여소 번호', value: reservation.station_id.toString()),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEEEEEE),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18))),
                    ),
                    child: const Text('스테이션 위치 보기'),
                  ),
                ),
                Center(child: Container(width: 1, height: 25, color: const Color(0xFFD9D9D9))),
                Expanded(
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(18))),
                    ),
                    child: const Text('예약 취소'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            '$label :',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF222222)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF222222)),
          ),
        ),
      ],
    );
  }
}
