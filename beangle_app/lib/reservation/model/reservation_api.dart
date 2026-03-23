import 'dart:convert';

import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:http/http.dart' as http;

class ReservationApi {
  ReservationApi({
    //
    http.Client? client,
    this.baseUrl = 'http://127.0.0.1:8000', //'http://127.0.0.1:8000',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<ReservationInfo> fetchReservation() async {
    // Replace this temporary sample with the real endpoint when the API is ready.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return ReservationInfo(
      reservation_id: 0,
      user_id: 1,
      station_id: 0,
      time: DateTime.parse('2026-03-09 10:00:00'),
      is_cancel: 0,
      // notice: '- 예약대여 후 대여시간 안에 정상 반납시 24시간 동안은 대여횟수 제한없이 예약가능.',
      imagePath: 'images/beangle_back.png',
    );
  }

  Future<ReservationInfo> fetchReservationById({required int reservationId}) async {
    final uri = Uri.parse('$baseUrl/reservation/selectById/$reservationId');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ReservationInfo.fromJson(json);
  }

  Future<int> insertReservation(ReservationInfo reservation) async {
    print('======');
    print(jsonEncode(reservation.toJson()));

    // final J = {
    //   //
    //   "reservation_id": 0,
    //   "user_id": 111,
    //   "station_id": 111,
    //   "time": "2026-03-23",
    //   "is_cancel": 0,
    // };

    final uri = Uri.parse('$baseUrl/reservation/insert');
    final response = await _client.post(
      //
      uri,

      headers: {
        //
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(reservation.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['result'];
  }

  Future<int> insertReservations(List<Map<String, dynamic>> data) async {
    // final J = {
    //   //
    //   "reservation_id": 0,
    //   "user_id": 111,
    //   "station_id": 111,
    //   "time": "2026-03-23",
    //   "is_cancel": 0,
    // };

    final uri = Uri.parse('$baseUrl/reservation/inserts');
    final response = await _client.post(
      //
      uri,

      headers: {
        //
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['result'];
  }

  // reservation 불러오기
  // Future<List<ReservationInfo>> fetchReservations() async {
  Future<List<dynamic>> fetchReservations() async {
    final uri = Uri.parse('$baseUrl/reservation/select');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json["results"].length > 0) {}
    List<dynamic> reservation = json["results"].map((d) => ReservationInfo.fromJson(d)).toList();

    print(reservation);

    return reservation;
  }
}
