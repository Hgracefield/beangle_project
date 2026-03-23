import 'dart:convert';

import 'package:beangle_app/app_shell.dart';
import 'package:beangle_app/reservation/model/reservation_api.dart';
import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:beangle_app/reservation/widgets/illu_widget.dart';
import 'package:beangle_app/reservation/widgets/reservation_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ReservationPage extends StatelessWidget {
  const ReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(title: '예약 ', currentRoute: AppRoutes.reservation, body: const _ReservationView());
  }
}

class _ReservationView extends StatefulWidget {
  const _ReservationView();

  @override
  State<_ReservationView> createState() => _ReservationViewState();
}

class _ReservationViewState extends State<_ReservationView> {
  late final Future<ReservationInfo> _reservationFuture;
  late final List<ReservationInfo> ddd = [];
  late final GetStorage _storage;
  late final Map<dynamic, dynamic>? reservations;
  String? _userId;
  @override
  void initState() {
    super.initState();
    //final api = ReservationApi();
    _reservationFuture = ReservationApi().fetchReservation();
    // _reservationFutureapi.fetchReservationById(reservationId: 1) as Future<ReservationInfo>;
    // getReservation();
    _storage = GetStorage();
    reservations = _storage.read<Map<dynamic, dynamic>>('station_reservations');
    _userId = _storage.read('user_id')?.toString();
    print('======');
    print("reservations: ${reservations}");
    print("user_id: ${_userId}");
    createReservations();
  }

  void createReservations() async {
    // 키값만 가져오기
    List<Map<String, dynamic>> test = [];
    final keys = reservations!.keys.toList();
    for (String k in keys) {
      final station_id = k.split('-')[1];
      for (var v in reservations![k]) {
        // Create Reservation
        ddd.add(
          ReservationInfo.fromJson({
            //
            'reservation_id': 0,
            'user_id': int.parse(_userId!),
            'station_id': int.parse(station_id),
            'time': v,
            'is_cancel': 0,
          }),
        );
      }
    }

    //ReservationApi().insertReservations(test);

    // reservations.map((key, value) => ReservationInfo(user_id: user_id, station_id: station_id, time: time, is_cancel: 0));
  }

  // void getReservation() async {
  //   final api = ReservationApi();
  //   _reservationFuture = await api.fetchReservationById(reservationId: 1) as Future<ReservationInfo>;
  //   // _reservationFuture = await api.fetchReservations();
  // }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      //
      itemCount: ddd.length,
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // _NoticeBanner(
              //   message: reservation.notice,
              //   textStyle: Theme.of(
              //     context,
              //   ).textTheme.titleMedium?.copyWith(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
              // ),
              const SizedBox(height: 18),
              //ReservationCardWidget(reservation: ddd[index]),
              cardWidget(ddd[index], index),
              // const SizedBox(height: 28),
              // IlluWidget(imagePath: reservation.imagePath),
            ],
          ),
        );
      },
    );
  }

  // Methods insert Reservation
  Future<void> insertReservation(ReservationInfo reservation, int index) async {
    // ReservationInfo test = ReservationInfo(
    //   //
    //   reservation_id: 0,
    //   user_id: 1,
    //   station_id: 444,
    //   time: DateTime.parse('2026-01-01'),
    //   is_cancel: 0,
    // );

    final result = await ReservationApi().insertReservation(reservation);
    if (result == 1) {
      // Display Success Message
      // Remove current index
      ddd.removeAt(index);
      // Storage에서도 삭제 해야함.
      final key = "ST-" + reservation.station_id.toString();

      for (var d in reservations![key]) {
        if (d == reservation.time.toIso8601String()) {
          reservations![key].remove(d);
        }
      }

      _storage.write('station_reservations', reservations);
      setState(() {});
      Get.snackbar("Success", "성공적으로 예약이 됬습니다.");
    } else {
      // Display Error Message
      Get.snackbar("Error", "예약중에 에러가 발생했습니다.");
    }
  }

  // === Widget
  Widget cardWidget(ReservationInfo reservation, int index) {
    print("---- ${reservation.time}");
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
                ReservationRow(
                  '예약 일자',
                  reservation.time.year.toString() + '-' + reservation.time.month.toString() + '-' + reservation.time.day.toString(),
                ),
                const SizedBox(height: 16),
                ReservationRow('예약 시간', reservation.time.hour.toString()),
                const SizedBox(height: 16),
                ReservationRow('대여소 번호', "ST-" + reservation.station_id.toString()),
                ReservationRow('생성 날짜', reservation.time.toString()),
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
                    onPressed: () {
                      Get.back();
                    },
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
                    onPressed: () async {
                      await insertReservation(reservation, index);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(18))),
                    ),
                    child: const Text('예약 하기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget ReservationRow(String label, String value) {
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
//   Widget build(BuildContext context) {
//     return FutureBuilder<ReservationInfo>(
//       future: _reservationFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         if (snapshot.hasError) {
//           return Center(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//               child: Text(
//                 '\uC608\uC57D \uB300\uC5EC \uD6C4 \uB300\uC5EC\uC2DC\uAC04 \uC548\uC5D0 \uC815\uC0C1 \uBC18\uB0A9\uC2DC 24\uC2DC\uAC04 \uB3D9\uC548\uC740 \uB300\uC5EC\uD69F\uC218 \uC81C\uD55C\uC5C6\uC774 \uC608\uC57D\uAC00\uB2A5.',
//                 textAlign: TextAlign.center,
//                 style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 12),
//               ),
//             ),
//           );
//         }

//         final reservation = snapshot.data ?? ReservationInfo.empty();

//         return SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // _NoticeBanner(
//               //   message: reservation.notice,
//               //   textStyle: Theme.of(
//               //     context,
//               //   ).textTheme.titleMedium?.copyWith(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
//               // ),
//               const SizedBox(height: 18),
//               ReservationCardWidget(reservation: reservation),
//               const SizedBox(height: 28),
//               // IlluWidget(imagePath: reservation.imagePath),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, this.textStyle});

  final String message;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: textStyle ?? Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.45, fontWeight: FontWeight.w600));
  }
}
