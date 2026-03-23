import 'dart:convert';

import 'package:beangle_app/worker/view/cycle_station_marker.dart';
import 'package:beangle_app/worker/model/cycle_station.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapForWorkerPage extends StatefulWidget {
  const MapForWorkerPage({super.key});

  @override
  State<MapForWorkerPage> createState() => _MapForWorkerPageState();
}

class _MapForWorkerPageState extends State<MapForWorkerPage> {

  // === Property === 
  final _mapCenter = LatLng(37.6177, 126.9227); // 시작 맵 좌표
  final _stationIds = <String>[
    'ST-481',
    'ST-2425',
    'ST-1331',
    'ST-454',
    'ST-453',
    // 'ST-1482',
  ]; // 보여줄 스테이션 번호
  final _apiKey = '595975485377617236307a746f5179'; // 따릉이 api key

  bool _isLoading = true; // 로딩 완료 여부
  String? _errorMessage; // 에러 메시지
  List<CycleStation> _stations = const [];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  

  @override
  Widget build(BuildContext context) {
    final visibleStations = _stations;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: Color(0xFF3657C8),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isLoading
                      ? '스테이션 정보를 불러오는 중입니다.'
                      : '재배치가 필요한 따릉이 위치를 확인하세요.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadStations,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: '새로고침',
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 13.2,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.beangle_app',
                      ),
                      MarkerLayer(
                        markers: visibleStations.map((station) {
                          return Marker(
                            point: station.location,
                            width: 200,
                            height: 96,
                            child: CycleStationMarker(station: station),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '실시간 배치 현황',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (!_isLoading) ...[
                              const SizedBox(height: 6),
                              Text('조회 스테이션 ${visibleStations.length}곳'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isLoading) const Center(child: CircularProgressIndicator()),
                  if (_errorMessage != null)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadStations,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  } // build

  // === Functions === 
  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stations = await Future.wait(_stationIds.map(_fetchStation));
      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '스테이션 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<CycleStation> _fetchStation(String stationId) async {
    final uri = Uri.parse(
      'http://openapi.seoul.go.kr:8088/$_apiKey/json/bikeList/1/1/$stationId',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load station: $stationId');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final bikeStatus = decoded['rentBikeStatus'] as Map<String, dynamic>?;
    final rows = bikeStatus?['row'] as List<dynamic>?;

    if (rows == null || rows.isEmpty) {
      throw Exception('Empty station data: $stationId');
    }

    final row = rows.first as Map<String, dynamic>;
    final latitude = double.tryParse(row['stationLatitude']?.toString() ?? '');
    final longitude =
        double.tryParse(row['stationLongitude']?.toString() ?? '');

    if (latitude == null || longitude == null) {
      throw Exception('Invalid coordinates: $stationId');
    }
    return CycleStation(
      id: stationId,
      name: row['stationName']?.toString() ?? stationId,
      parkingCount: int.tryParse(row['parkingBikeTotCnt']?.toString() ?? '') ?? 0,
      rackCount: int.tryParse(row['rackTotCnt']?.toString() ?? '') ?? 0,
      location: LatLng(latitude, longitude),
    );
  }
}