import 'dart:convert';

import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ReservationApi {
  ReservationApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _client;
  final String? _baseUrl;

  String get baseUrl {
    if (_baseUrl != null) {
      return _baseUrl;
    }
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

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

  Future<ReservationInfo> fetchReservationById({
    required int reservationId,
  }) async {
    final uri = Uri.parse('$baseUrl/reservation/selectById/$reservationId');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> results =
        json['results'] as List<dynamic>? ?? <dynamic>[];
    if (results.isEmpty) {
      throw Exception('Reservation not found');
    }
    return ReservationInfo.fromJson(results.first as Map<String, dynamic>);
  }

  Future<int> insertReservation(ReservationInfo reservation) async {
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

  Future<List<ReservationInfo>> fetchReservations() async {
    final uri = Uri.parse('$baseUrl/reservation/select');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservation');
    }

    return _parseReservationList(response.body);
  }

  Future<List<ReservationInfo>> fetchReservationsByUserId({
    required int userId,
  }) async {
    final uri = Uri.parse('$baseUrl/reservation/selectByUserId/$userId');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load reservations by user');
    }

    return _parseReservationList(response.body);
  }

  Future<int> deleteReservation(ReservationInfo reservation) async {
    final ReservationInfo canceledReservation = ReservationInfo(
      reservation_id: reservation.reservation_id,
      user_id: reservation.user_id,
      station_id: reservation.station_id,
      time: reservation.time,
      is_cancel: 1,
      imagePath: reservation.imagePath,
    );
    final uri = Uri.parse('$baseUrl/reservation/delete');
    final response = await _client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(canceledReservation.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete reservation');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return json['result'] as int? ?? 0;
  }

  List<ReservationInfo> _parseReservationList(String responseBody) {
    final Map<String, dynamic> json =
        jsonDecode(responseBody) as Map<String, dynamic>;
    final List<dynamic> results =
        json['results'] as List<dynamic>? ?? <dynamic>[];
    return results
        .map(
          (dynamic item) =>
              ReservationInfo.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
