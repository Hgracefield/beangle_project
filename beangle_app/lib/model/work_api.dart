import 'dart:convert';

import 'package:beangle_app/model/work_record.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WorkApi {
  WorkApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _client;
  final String? _baseUrl;

  String get baseUrl {
    if (_baseUrl != null) {
      return _baseUrl!;
    }
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  Future<List<WorkRecord>> fetchWorks() async {
    final uri = Uri.parse('$baseUrl/work/selectAll');
    final response = await _client.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load work records');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> results =
        json['results'] as List<dynamic>? ?? <dynamic>[];
    return results
        .map(
          (dynamic item) => WorkRecord.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<int> insertWork(WorkRecord work) async {
    final uri = Uri.parse('$baseUrl/work/insert');
    final response = await _client.post(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(work.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to insert work record');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return json['result'] == 'OK' ? 1 : 0;
  }

  Future<bool> createWorkRequest({
    required int workerId,
    required int stationId,
    required DateTime worktime,
    required String requestMessage,
  }) async {
    final uri = Uri.parse('$baseUrl/work/request');
    final response = await _client.post(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'worker_id': workerId,
        'station_id': stationId,
        'worktime': worktime.toIso8601String(),
        'request_message': requestMessage,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create work request');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return json['result'] == 'OK';
  }
}
