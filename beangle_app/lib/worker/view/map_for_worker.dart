import 'dart:convert';
import 'package:beangle_app/auth/auth_page.dart';
import 'package:beangle_app/common/common_color.dart';
import 'package:beangle_app/worker/model/work_api.dart';
import 'package:beangle_app/worker/model/work_record.dart';
import 'package:beangle_app/worker/view/cycle_station_marker.dart';
import 'package:beangle_app/worker/view/worker_theme.dart';
import 'package:beangle_app/worker/model/cycle_station.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:get/get_core/get_core.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapForWorkerPage extends StatefulWidget {
  const MapForWorkerPage({super.key});

  @override
  State<MapForWorkerPage> createState() => _MapForWorkerPageState();
}

class _FlowSummary {
  const _FlowSummary({required this.inflow, required this.outflow});

  final double inflow;
  final double outflow;
}

class _MapForWorkerPageState extends State<MapForWorkerPage> {

  // === Property === 
  static const String _workerIdStorageKey = 'worker_id';
  static const String _themeStorageKey = 'worker_map_dark_theme';

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

  final  String _predictionAssetPath =
      'assets/data/station_hourly_predictions.json';

  bool _isLoading = true; // 로딩 완료 여부
  String? _errorMessage; // 에러 메시지
  List<CycleStation> _stations = const [];
  Set<int> _completedStationIds = <int>{};
  String? _workerId = '';
  bool isDarkTheme = false;
  final GetStorage _storage = GetStorage();
  final WorkApi _workApi = WorkApi();
  Map<String, dynamic> _predictionData = const {};

  @override
  void initState() {
    super.initState();
    _loadPredictionData();
    _loadStations();
    _loadCompletedStations();
    _workerId = _storage.read(_workerIdStorageKey)?.toString();
  }

  

  @override
  Widget build(BuildContext context) {
    final visibleStations = _stations;
    final now = DateTime.now();
    final nextRelocationTime = _nextRelocationTime(now);
    final nextRelocationLabel = _formatRelocationLabel(nextRelocationTime);
    final followingRelocationTime =
        _followingRelocationTime(nextRelocationTime);
    final followingRelocationLabel =
        _formatRelocationLabel(followingRelocationTime);
    // print(nextRelocationLabel);
    return Scaffold(
       appBar: AppBar(
        backgroundColor: workerThemeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // leading: IconButton(
        //   icon: const Icon(Icons.menu),
        //   onPressed: () {},
        // ),
        title: const Text(
          '따릉이 재배치',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child:  IconButton(
                onPressed: _isLoading ? null : _loadStations,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: '새로고침',
              ),
          ),
        ],
      ),
      drawer: Drawer(
          backgroundColor: CommonColor.panelColor(isDarkTheme),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CommonColor.cardAccent(), CommonColor.cardAccent().withValues(alpha: 0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '',
                                // _userName.isEmpty ? '게스트 사용자' : _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.brightness_4, color: CommonColor.primaryTextColor(isDarkTheme)),
                title: Text('다크테마', style: TextStyle(color: CommonColor.primaryTextColor(isDarkTheme))),
                trailing: Switch(
                  value: isDarkTheme,
                  onChanged: (bool value) {
                    setState(() {
                      isDarkTheme = value;
                    });
                    _persistTheme();
                  },
                ),
              ),
              
              ListTile(
                leading: Icon(Icons.logout, color: CommonColor.primaryTextColor(isDarkTheme)),
                title: Text('로그아웃', style: TextStyle(color: CommonColor.primaryTextColor(isDarkTheme))),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ],
          ),
        ),
      body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: workerThemeColor,
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
                          final nowHour =
                              DateTime(now.year, now.month, now.day, now.hour);
                          final flowToNext = _cumulativeFlowBetween(
                            station.id,
                            nowHour,
                            nextRelocationTime,
                          );
                          final flowNextToFollowing = _cumulativeFlowBetween(
                            station.id,
                            nextRelocationTime,
                            followingRelocationTime,
                          );
                          return Marker(
                            point: station.location,
                            width: 200,
                            height: 96,
                            child: CycleStationMarker(
                              station: station,
                              isCompleted: _completedStationIds.contains(
                                int.tryParse(station.id.replaceFirst('ST-', '')),
                              ),
                              onWorkSubmitted: _loadCompletedStations,
                              currentTime: now,
                              nextRelocationTime: nextRelocationTime,
                              currentTimeLabel: _formatHourLabel(now),
                              nextRelocationLabel: nextRelocationLabel,
                              currentCount: station.parkingCount,
                              cumulativeInflow: flowNextToFollowing?.inflow,
                              cumulativeOutflow: flowNextToFollowing?.outflow,
                              preInflow: flowToNext?.inflow,
                              preOutflow: flowToNext?.outflow,
                            ),
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
                              const SizedBox(height: 4),
                              Text('작업 완료 ${_completedStationIds.length}곳'),
                              if (_predictionData.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '재배치 누적: $nextRelocationLabel → $followingRelocationLabel',
                              ),
                            ],
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
    )
    );
  } // build

  // === Functions === 

  Future<void> _loadCompletedStations() async {
    try {
      final DateTime slotTime = _nextRelocationTime(DateTime.now());
      final List<WorkRecord> works = await _workApi.fetchWorks();
      final Set<int> completedIds =
          works
              .where((WorkRecord item) => _isSameSlot(item.time, slotTime))
              .map((WorkRecord item) => item.stationId)
              .toSet();

      if (!mounted) {
        return;
      }

      setState(() {
        _completedStationIds = completedIds;
      });
    } catch (_) {
      // Ignore completion indicator refresh failures.
    }
  }

  bool _isSameSlot(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour;
  }

  DateTime _nextRelocationTime(DateTime now) {
    final todayFour = DateTime(now.year, now.month, now.day, 4);
    final todaySixteen = DateTime(now.year, now.month, now.day, 16);

    if (now.isBefore(todayFour) || now.isAtSameMomentAs(todayFour)) {
      return todayFour;
    }
    if (now.isBefore(todaySixteen) || now.isAtSameMomentAs(todaySixteen)) {
      return todaySixteen;
    }
    return DateTime(now.year, now.month, now.day + 1, 4);
  }

  DateTime _followingRelocationTime(DateTime nextRelocationTime) {
    if (nextRelocationTime.hour == 4) {
      return DateTime(
        nextRelocationTime.year,
        nextRelocationTime.month,
        nextRelocationTime.day,
        16,
      );
    }
    return DateTime(
      nextRelocationTime.year,
      nextRelocationTime.month,
      nextRelocationTime.day + 1,
      4,
    );
  }

  String _formatRelocationLabel(DateTime target) {
    return target.hour == 4 ? '오전 4시' : '오후 4시';
  }

  String _formatHourLabel(DateTime target) {
    final hour = target.hour;
    final isAm = hour < 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return isAm ? '오전 ${displayHour}시' : '오후 ${displayHour}시';
  }

  _FlowSummary? _lookupFlowSummary(String stationId, DateTime target) {
    final stationData = _predictionData[stationId];
    if (stationData is! Map) {
      return null;
    }
    final slots = stationData['slots'];
    if (slots is! Map) {
      return null;
    }

    final monthKey = target.month.toString();
    final weekdayKey = (target.weekday - 1).toString();
    final hourKey = target.hour.toString();

    final monthData = slots[monthKey];
    if (monthData is! Map) {
      return null;
    }
    final dayData = monthData[weekdayKey];
    if (dayData is! Map) {
      return null;
    }
    final hourData = dayData[hourKey];
    if (hourData is! Map) {
      return null;
    }

    final inflow = hourData['inflow'];
    final outflow = hourData['outflow'];
    final inflowValue =
        inflow is num ? inflow.toDouble() : double.tryParse(inflow?.toString() ?? '');
    final outflowValue =
        outflow is num ? outflow.toDouble() : double.tryParse(outflow?.toString() ?? '');
    if (inflowValue == null && outflowValue == null) {
      return null;
    }
    return _FlowSummary(inflow: inflowValue ?? 0, outflow: outflowValue ?? 0);
  }

  _FlowSummary? _cumulativeFlowBetween(
    String stationId,
    DateTime start,
    DateTime end,
  ) {
    double inflowSum = 0;
    double outflowSum = 0;
    var found = false;
    for (var cursor = start;
        cursor.isBefore(end);
        cursor = cursor.add(const Duration(hours: 1))) {
      final flow = _lookupFlowSummary(stationId, cursor);
      if (flow != null) {
        inflowSum += flow.inflow;
        outflowSum += flow.outflow;
        found = true;
      }
    }
    return found ? _FlowSummary(inflow: inflowSum, outflow: outflowSum) : null;
  }

  Future<void> _loadPredictionData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        _predictionAssetPath,
      );
      final Map<String, dynamic> parsed =
          jsonDecode(jsonString) as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      setState(() {
        _predictionData = parsed;
        // _predictionStatus = '학습 모델 예측 변동량 준비 완료';
      });
    } catch (e) {
      debugPrint('예측 데이터 로딩 실패: $e');
      if (!mounted) {
        return;
      }

      setState(() {
        // _predictionStatus = '예측 변동량 없음';
      });
    }
  }
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
  void _persistTheme() {
    _storage.write(_themeStorageKey, isDarkTheme);
  }
  Future<void> _logout() async {
    // 로그인 사용자 식별값을 지우고 로그인 화면으로 복귀한다.
    await _storage.remove(_workerIdStorageKey);
    if (!mounted) {
      return;
    }

    setState(() {
      _workerId = null;
    });

    Get.offAll(() => const AuthPage());
  }
}
