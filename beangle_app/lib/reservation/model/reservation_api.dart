import 'dart:convert';

import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:http/http.dart' as http;

class ReservationApi {
  ReservationApi({
    http.Client? client,
    this.baseUrl = 'https://example.com',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<ReservationInfo> fetchReservation() async {
    // Replace this temporary sample with the real endpoint when the API is ready.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const ReservationInfo(
      dateText: '2026.03.09',
      timeText: '10:00',
      stationCode: 'ST-453',
      notice: '- 예약대여 후 대여시간 안에 정상 반납시 24시간 동안은 대여횟수 제한없이 예약가능.',
      imagePath: 'images/beangle_back.png',
    );
  }

  Future<ReservationInfo> fetchReservationFromServer({
    required String reservationId,
  }) async {
    final uri = Uri.parse('$baseUrl/reservations/$reservationId');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ReservationInfo.fromJson(json);
  }
}
