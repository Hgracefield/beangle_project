import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;

class MapForUserPage extends StatefulWidget {
  const MapForUserPage({super.key});

  @override
  State<MapForUserPage> createState() => _MapForUserPageState();
}

class _MapForUserPageState extends State<MapForUserPage> {
  static const String _bikeApiKey = '595975485377617236307a746f5179';
  static const String _predictionAssetPath =
      'assets/data/station_hourly_predictions.json';
  static const String _favoriteStorageKey = 'favorite_station_ids';
  static const String _themeStorageKey = 'user_map_dark_theme';
  static const String _reservationStorageKey = 'station_reservations';

  final MapController _mapController = MapController();
  final GetStorage _storage = GetStorage();

  late latlong.LatLng _currentPosition;
  List<Marker> _markers = [];
  Set<String> _favoriteStationIds = <String>{};
  Map<String, Map<int, int>> _reservedCounts = <String, Map<int, int>>{};
  String? _selectedStationId;

  bool _isDarkTheme = false;
  bool _isWeatherExpanded = true;
  bool _isControlPanelExpanded = true;
  bool _isUsingCurrentWeather = true;
  bool _isWeatherLoading = false;
  bool _isStationLoading = false;

  int _selectedForecastHour = 1;

  String _weatherInfo = '날씨 정보 로딩 중...';
  String _temperature = '--';
  String _humidity = '--';
  String _precipitation = '--';
  String _snowfall = '--';
  String _discomfortIndex = '--';
  String _stationStatus = '실시간 대수 불러오는 중...';
  String _predictionStatus = '예측 변동량 불러오는 중...';

  Map<String, dynamic> _predictionData = const {};

  final Map<String, Map<String, dynamic>> _stations = {
    'ST-481': {
      'name': '상현',
      'number': '933',
      'lat': 37.612484,
      'lng': 126.914879,
      'available': 9,
      'parking': 6,
    },
    'ST-2425': {
      'name': '다원',
      'number': '4652',
      'lat': 37.600000,
      'lng': 126.920000,
      'available': 0,
      'parking': 0,
    },
    'ST-1331': {
      'name': '찬솔',
      'number': '956',
      'lat': 37.594414,
      'lng': 126.918015,
      'available': 10,
      'parking': 8,
    },
    'ST-454': {
      'name': '신영',
      'number': '906',
      'lat': 37.61721,
      'lng': 126.919579,
      'available': 5,
      'parking': 4,
    },
    'ST-453': {
      'name': '혜전',
      'number': '905',
      'lat': 37.636234,
      'lng': 126.918999,
      'available': 11,
      'parking': 9,
    },
  };

  @override
  void initState() {
    super.initState();
    _currentPosition = const latlong.LatLng(37.615, 126.917);
    _hydrateLocalState();
    _loadPredictionData();
    _loadStations();
    Future.delayed(const Duration(milliseconds: 100), _fitMarkersOnMap);
    _getCurrentLocation();
    _fetchWeather();
  }

  void _hydrateLocalState() {
    final List<dynamic>? favorites = _storage.read<List<dynamic>>(
      _favoriteStorageKey,
    );
    final Map<dynamic, dynamic>? reservations = _storage
        .read<Map<dynamic, dynamic>>(_reservationStorageKey);

    _isDarkTheme = _storage.read<bool>(_themeStorageKey) ?? false;
    _favoriteStationIds = (favorites ?? <dynamic>[])
        .map((dynamic id) => id.toString())
        .toSet();
    _reservedCounts = _decodeReservedCounts(reservations);
  }

  Map<String, Map<int, int>> _decodeReservedCounts(Map<dynamic, dynamic>? raw) {
    final Map<String, Map<int, int>> decoded = <String, Map<int, int>>{};
    if (raw == null) {
      return decoded;
    }

    raw.forEach((dynamic stationId, dynamic offsetMap) {
      if (offsetMap is! Map) {
        return;
      }
      final Map<int, int> stationReservations = <int, int>{};
      offsetMap.forEach((dynamic hour, dynamic count) {
        final int? parsedHour = int.tryParse(hour.toString());
        final int? parsedCount = int.tryParse(count.toString());
        if (parsedHour == null || parsedCount == null || parsedCount <= 0) {
          return;
        }
        stationReservations[parsedHour] = parsedCount;
      });
      if (stationReservations.isNotEmpty) {
        decoded[stationId.toString()] = stationReservations;
      }
    });

    return decoded;
  }

  void _persistFavorites() {
    _storage.write(_favoriteStorageKey, _favoriteStationIds.toList()..sort());
  }

  void _persistTheme() {
    _storage.write(_themeStorageKey, _isDarkTheme);
  }

  void _persistReservations() {
    final Map<String, Map<String, int>> encoded = <String, Map<String, int>>{};
    _reservedCounts.forEach((String stationId, Map<int, int> offsets) {
      final Map<String, int> filtered = <String, int>{};
      offsets.forEach((int hour, int count) {
        if (count > 0) {
          filtered['$hour'] = count;
        }
      });
      if (filtered.isNotEmpty) {
        encoded[stationId] = filtered;
      }
    });
    _storage.write(_reservationStorageKey, encoded);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = latlong.LatLng(
          position.latitude,
          position.longitude,
        );
      });

      _mapController.move(_currentPosition, 15.0);
      await _fetchWeather();
    } catch (e) {
      debugPrint('위치 가져오기 실패: $e');
    }
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
        _predictionStatus = '학습 모델 예측 변동량 준비 완료';
      });
      _rebuildMarkers();
    } catch (e) {
      debugPrint('예측 데이터 로딩 실패: $e');
      if (!mounted) {
        return;
      }

      setState(() {
        _predictionStatus = '예측 변동량 없음';
      });
    }
  }

  Future<void> _loadStations() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isStationLoading = true;
      _stationStatus = '실시간 대수 불러오는 중...';
    });

    try {
      final List<String> stationIds = _stations.keys.toList();
      final List<MapEntry<String, _StationAvailability>> stationUpdates =
          await Future.wait(
            stationIds.map((String id) async {
              return MapEntry<String, _StationAvailability>(
                id,
                await _fetchStationAvailability(id),
              );
            }),
          );

      if (!mounted) {
        return;
      }

      for (final MapEntry<String, _StationAvailability> entry
          in stationUpdates) {
        final Map<String, dynamic>? station = _stations[entry.key];
        if (station == null) {
          continue;
        }
        station['name'] = entry.value.name;
        station['available'] = entry.value.available;
        station['parking'] = entry.value.parking;
        station['lat'] = entry.value.latitude;
        station['lng'] = entry.value.longitude;
      }

      _rebuildMarkers();
      setState(() {
        _isStationLoading = false;
        _stationStatus = '실시간 대수 반영 완료';
      });
    } catch (e) {
      debugPrint('대여소 정보 가져오기 실패: $e');
      if (!mounted) {
        return;
      }

      _rebuildMarkers();
      setState(() {
        _isStationLoading = false;
        _stationStatus = '기본 대여소 정보 표시 중';
      });
    }
  }

  Future<_StationAvailability> _fetchStationAvailability(
    String stationId,
  ) async {
    final Uri uri = Uri.parse(
      'http://openapi.seoul.go.kr:8088/$_bikeApiKey/json/bikeList/1/1/$stationId',
    );
    final http.Response response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('대여소 조회 실패: $stationId');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic>? bikeStatus =
        decoded['rentBikeStatus'] as Map<String, dynamic>?;
    final List<dynamic>? rows = bikeStatus?['row'] as List<dynamic>?;

    if (rows == null || rows.isEmpty) {
      throw Exception('대여소 데이터 없음: $stationId');
    }

    final Map<String, dynamic> row = rows.first as Map<String, dynamic>;
    final int available =
        int.tryParse(row['parkingBikeTotCnt']?.toString() ?? '') ?? 0;
    final int rackCount =
        int.tryParse(row['rackTotCnt']?.toString() ?? '') ?? 0;
    final double latitude =
        double.tryParse(row['stationLatitude']?.toString() ?? '') ??
        (_stations[stationId]?['lat'] as double);
    final double longitude =
        double.tryParse(row['stationLongitude']?.toString() ?? '') ??
        (_stations[stationId]?['lng'] as double);

    return _StationAvailability(
      name:
          (_stations[stationId]?['name'] as String?) ??
          row['stationName']?.toString() ??
          stationId,
      available: available,
      parking: (rackCount - available).clamp(0, rackCount),
      latitude: latitude,
      longitude: longitude,
    );
  }

  List<MapEntry<String, Map<String, dynamic>>> _sortedStationEntries() {
    final List<MapEntry<String, Map<String, dynamic>>> entries = _stations
        .entries
        .toList();
    entries.sort((
      MapEntry<String, Map<String, dynamic>> a,
      MapEntry<String, Map<String, dynamic>> b,
    ) {
      final bool aFavorite = _favoriteStationIds.contains(a.key);
      final bool bFavorite = _favoriteStationIds.contains(b.key);
      if (aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }
      return (a.value['name'] as String).compareTo(b.value['name'] as String);
    });
    return entries;
  }

  void _rebuildMarkers() {
    final List<Marker> markers = <Marker>[];
    for (final MapEntry<String, Map<String, dynamic>> entry
        in _sortedStationEntries()) {
      final String id = entry.key;
      final Map<String, dynamic> data = entry.value;
      markers.add(
        Marker(
          point: latlong.LatLng(data['lat'] as double, data['lng'] as double),
          width: 120,
          height: 86,
          child: GestureDetector(
            onTap: () => _showStationDialog(id, data),
            child: _StationMarkerChip(
              stationName: data['name'] as String,
              currentAvailable: data['available'] as int,
              predictedAvailable: _calculatePredictedAvailability(id, data),
              color: _getMarkerColor(data['available'] as int),
              isFavorite: _favoriteStationIds.contains(id),
              isSelected: _selectedStationId == id,
            ),
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _markers = markers;
    });
  }

  Color _getMarkerColor(int available) {
    if (available <= 3) {
      return const Color(0xFFD14D4D);
    }
    if (available <= 6) {
      return const Color(0xFFF0A23A);
    }
    return const Color(0xFF49992E);
  }

  Future<void> _fetchWeather() async {
    final DateTime now = DateTime.now();
    final DateTime targetDateTime = _isUsingCurrentWeather
        ? now
        : now.add(Duration(hours: _selectedForecastHour));

    if (!mounted) {
      return;
    }

    setState(() {
      _isWeatherLoading = true;
      _weatherInfo = _isUsingCurrentWeather
          ? '현재 날씨 불러오는 중...'
          : '선택한 시간의 날씨 불러오는 중...';
    });

    try {
      final Uri
      url = Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
        'latitude': _currentPosition.latitude.toString(),
        'longitude': _currentPosition.longitude.toString(),
        'timezone': 'Asia/Seoul',
        'forecast_days': '7',
        'current':
            'temperature_2m,relative_humidity_2m,precipitation,snowfall,weather_code',
        'hourly':
            'temperature_2m,relative_humidity_2m,precipitation,snowfall,weather_code',
      });

      final http.Response response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('날씨 API 오류: ${response.statusCode}');
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final _WeatherSnapshot snapshot = _isUsingCurrentWeather
          ? _parseCurrentWeather(data)
          : _parseHourlyWeather(data, targetDateTime);

      if (!mounted) {
        return;
      }

      setState(() {
        _temperature = '${snapshot.temperature.toStringAsFixed(1)}°C';
        _humidity = '${snapshot.humidity}%';
        _precipitation = '${snapshot.precipitation.toStringAsFixed(1)}mm';
        _snowfall = '${snapshot.snowfall.toStringAsFixed(1)}cm';
        _discomfortIndex =
            '${_calculateDiscomfortIndex(snapshot.temperature, snapshot.humidity)}';
        _weatherInfo = snapshot.summary;
        _isWeatherLoading = false;
      });
    } catch (e) {
      debugPrint('날씨 정보 가져오기 실패: $e');
      if (!mounted) {
        return;
      }

      setState(() {
        _weatherInfo = '날씨 정보를 불러올 수 없습니다';
        _temperature = '--';
        _humidity = '--';
        _precipitation = '--';
        _snowfall = '--';
        _discomfortIndex = '--';
        _isWeatherLoading = false;
      });
    }
  }

  _WeatherSnapshot _parseCurrentWeather(Map<String, dynamic> data) {
    final Map<String, dynamic> current =
        data['current'] as Map<String, dynamic>;
    final int weatherCode = (current['weather_code'] as num?)?.toInt() ?? -1;

    return _WeatherSnapshot(
      summary: '현재 날씨 - ${_weatherCodeToKorean(weatherCode)}',
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0,
      snowfall: (current['snowfall'] as num?)?.toDouble() ?? 0,
    );
  }

  _WeatherSnapshot _parseHourlyWeather(
    Map<String, dynamic> data,
    DateTime targetDateTime,
  ) {
    final Map<String, dynamic> hourly = data['hourly'] as Map<String, dynamic>;
    final List<dynamic> times = hourly['time'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> temperatures =
        hourly['temperature_2m'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> humidities =
        hourly['relative_humidity_2m'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> precipitations =
        hourly['precipitation'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> snowfalls =
        hourly['snowfall'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> weatherCodes =
        hourly['weather_code'] as List<dynamic>? ?? <dynamic>[];

    if (times.isEmpty) {
      throw Exception('시간대별 예보 데이터가 비어 있습니다.');
    }

    int closestIndex = 0;
    int minDifference = DateTime.parse(
      times.first as String,
    ).difference(targetDateTime).inMinutes.abs();

    for (int i = 1; i < times.length; i++) {
      final int difference = DateTime.parse(
        times[i] as String,
      ).difference(targetDateTime).inMinutes.abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestIndex = i;
      }
    }

    final DateTime forecastTime = DateTime.parse(times[closestIndex] as String);
    final int weatherCode = (weatherCodes[closestIndex] as num?)?.toInt() ?? -1;

    return _WeatherSnapshot(
      summary:
          '${forecastTime.month}월 ${forecastTime.day}일 ${forecastTime.hour.toString().padLeft(2, '0')}시 - ${_weatherCodeToKorean(weatherCode)}',
      temperature: (temperatures[closestIndex] as num?)?.toDouble() ?? 0,
      humidity: (humidities[closestIndex] as num?)?.toInt() ?? 0,
      precipitation: (precipitations[closestIndex] as num?)?.toDouble() ?? 0,
      snowfall: (snowfalls[closestIndex] as num?)?.toDouble() ?? 0,
    );
  }

  int _calculateDiscomfortIndex(double temperature, int humidity) {
    final double index =
        0.81 * temperature +
        0.01 * humidity * (0.99 * temperature - 14.3) +
        46.3;
    return index.round();
  }

  String _weatherCodeToKorean(int code) {
    switch (code) {
      case 0:
        return '맑음';
      case 1:
      case 2:
        return '구름 조금';
      case 3:
        return '흐림';
      case 45:
      case 48:
        return '안개';
      case 51:
      case 53:
      case 55:
        return '이슬비';
      case 56:
      case 57:
        return '어는 이슬비';
      case 61:
      case 63:
      case 65:
        return '비';
      case 66:
      case 67:
        return '어는 비';
      case 71:
      case 73:
      case 75:
      case 77:
        return '눈';
      case 80:
      case 81:
      case 82:
        return '소나기';
      case 85:
      case 86:
        return '눈 소나기';
      case 95:
      case 96:
      case 99:
        return '뇌우';
      default:
        return '날씨 정보';
    }
  }

  int _calculatePredictedAvailability(
    String stationId,
    Map<String, dynamic> data,
  ) {
    final _ForecastOffsetSummary summary = _getForecastOffsetSummary(
      stationId,
      _selectedForecastHour,
    );
    final int currentAvailable = data['available'] as int? ?? 0;
    final int rackCount = currentAvailable + (data['parking'] as int? ?? 0);
    final int reservationImpact = _cumulativeReservedCount(
      stationId,
      _selectedForecastHour,
    );
    final int predicted =
        (currentAvailable + summary.netFlow).round() - reservationImpact;
    return predicted.clamp(0, rackCount);
  }

  _ForecastOffsetSummary _getForecastOffsetSummary(
    String stationId,
    int offsetHour,
  ) {
    final DateTime now = DateTime.now();
    final Map<String, dynamic>? predictionSlot = _lookupPredictionSlot(
      stationId,
      now,
    );
    final Map<String, dynamic>? offsets =
        predictionSlot?['offsets'] as Map<String, dynamic>?;
    final Map<String, dynamic>? selectedOffset =
        offsets?['$offsetHour'] as Map<String, dynamic>?;

    return _ForecastOffsetSummary(
      inflow: (selectedOffset?['inflow'] as num?)?.toDouble() ?? 0,
      outflow: (selectedOffset?['outflow'] as num?)?.toDouble() ?? 0,
      netFlow: (selectedOffset?['net_flow'] as num?)?.toDouble() ?? 0,
      targetTime: now.add(Duration(hours: offsetHour)),
    );
  }

  Map<String, dynamic>? _lookupPredictionSlot(
    String stationId,
    DateTime target,
  ) {
    final Map<String, dynamic>? stationMap =
        _predictionData[stationId] as Map<String, dynamic>?;
    final Map<String, dynamic>? slotMap =
        stationMap?['slots'] as Map<String, dynamic>?;
    final Map<String, dynamic>? monthMap =
        slotMap?['${target.month}'] as Map<String, dynamic>?;
    final Map<String, dynamic>? weekdayMap =
        monthMap?['${target.weekday - 1}'] as Map<String, dynamic>?;
    return weekdayMap?['${target.hour}'] as Map<String, dynamic>?;
  }

  int _cumulativeReservedCount(String stationId, int hour) {
    final Map<int, int> stationReservations =
        _reservedCounts[stationId] ?? <int, int>{};
    int total = 0;
    stationReservations.forEach((int offset, int count) {
      if (offset <= hour) {
        total += count;
      }
    });
    return total;
  }

  void _toggleFavorite(String stationId) {
    setState(() {
      if (_favoriteStationIds.contains(stationId)) {
        _favoriteStationIds.remove(stationId);
      } else {
        _favoriteStationIds.add(stationId);
      }
    });
    _persistFavorites();
    _rebuildMarkers();
  }

  void _removeFavorite(String stationId) {
    if (!_favoriteStationIds.contains(stationId)) {
      return;
    }
    setState(() {
      _favoriteStationIds.remove(stationId);
    });
    _persistFavorites();
    _rebuildMarkers();
  }

  void _focusStation(String stationId) {
    final Map<String, dynamic>? station = _stations[stationId];
    if (station == null) {
      return;
    }
    final latlong.LatLng target = latlong.LatLng(
      station['lat'] as double,
      station['lng'] as double,
    );
    setState(() {
      _selectedStationId = stationId;
    });
    _mapController.move(target, 15.3);
    _rebuildMarkers();
  }

  void _reserveSelectedStation() {
    final String? stationId = _selectedStationId;
    if (stationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 스테이션을 선택하세요.')));
      return;
    }

    final Map<String, dynamic>? station = _stations[stationId];
    if (station == null) {
      return;
    }

    final int predicted = _calculatePredictedAvailability(stationId, station);
    if (predicted <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 시간대에 예약 가능한 자전거가 없습니다.')),
      );
      return;
    }

    setState(() {
      final Map<int, int> stationReservations = _reservedCounts.putIfAbsent(
        stationId,
        () => <int, int>{},
      );
      stationReservations[_selectedForecastHour] =
          (stationReservations[_selectedForecastHour] ?? 0) + 1;
    });
    _persistReservations();
    _rebuildMarkers();

    final String stationName = station['name'] as String;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$stationName 예약 완료: $_selectedForecastHour시간 후 1대'),
      ),
    );
  }

  void _clearReservation(String stationId, int hour) {
    final Map<int, int>? stationReservations = _reservedCounts[stationId];
    if (stationReservations == null) {
      return;
    }

    setState(() {
      final int next = (stationReservations[hour] ?? 0) - 1;
      if (next > 0) {
        stationReservations[hour] = next;
      } else {
        stationReservations.remove(hour);
      }
      if (stationReservations.isEmpty) {
        _reservedCounts.remove(stationId);
      }
    });
    _persistReservations();
    _rebuildMarkers();
  }

  void _showStationDialog(String id, Map<String, dynamic> data) {
    final _ForecastOffsetSummary forecastSummary = _getForecastOffsetSummary(
      id,
      _selectedForecastHour,
    );
    final int predictedAvailable = _calculatePredictedAvailability(id, data);
    final int currentAvailable = data['available'] as int? ?? 0;
    final int predictedDelta = predictedAvailable - currentAvailable;
    final DateTime now = DateTime.now();
    final DateTime target =
        forecastSummary.targetTime ??
        now.add(Duration(hours: _selectedForecastHour));
    final int reservedCount =
        (_reservedCounts[id]?[_selectedForecastHour] ?? 0);

    setState(() {
      _selectedStationId = id;
    });
    _rebuildMarkers();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            brightness: _isDarkTheme ? Brightness.dark : Brightness.light,
            dialogTheme: DialogThemeData(backgroundColor: _panelColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _cardAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          child: AlertDialog(
            backgroundColor: _panelColor,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    data['name'] as String,
                    style: TextStyle(color: _primaryTextColor),
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleFavorite(id),
                  icon: Icon(
                    _favoriteStationIds.contains(id)
                        ? Icons.star
                        : Icons.star_border,
                    color: _favoriteStationIds.contains(id)
                        ? const Color(0xFFFFC94A)
                        : _secondaryTextColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardAccent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pedal_bike,
                        color: _cardAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                            label: '현재',
                            value: '$currentAvailable대',
                            labelColor: _labelTextColor,
                            valueColor: _primaryTextColor,
                          ),
                          _InfoLine(
                            label: '예측',
                            value:
                                '$predictedAvailable대 (${predictedDelta >= 0 ? '+' : ''}$predictedDelta)',
                            labelColor: _labelTextColor,
                            valueColor: _cardAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoLine(
                  label: '예측 유입량',
                  value: '${forecastSummary.inflow.toStringAsFixed(1)}대',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '예측 유출량',
                  value: '${forecastSummary.outflow.toStringAsFixed(1)}대',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '예측 순증감',
                  value: '${forecastSummary.netFlow.toStringAsFixed(1)}대',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '예약 반영',
                  value: '$reservedCount대',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '거치 가능',
                  value: '${data['parking']}대',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                const SizedBox(height: 10),
                _InfoLine(
                  label: '현재시간',
                  value: _formatDateTime(now),
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '예측시각',
                  value: _formatDateTime(target),
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
                _InfoLine(
                  label: '대여소 번호',
                  value: '${data['number'] ?? '-'}',
                  labelColor: _labelTextColor,
                  valueColor: _primaryTextColor,
                ),
              ],
            ),
            actions: [
              if (reservedCount > 0)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearReservation(id, _selectedForecastHour);
                  },
                  child: const Text('예약 취소'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectForecastHour(int? hour) {
    if (hour == null) {
      return;
    }
    setState(() {
      _selectedForecastHour = hour;
      _isUsingCurrentWeather = false;
    });
    _rebuildMarkers();
    _fetchWeather();
  }

  void _resetToCurrentWeather() {
    setState(() {
      _isUsingCurrentWeather = true;
    });
    _fetchWeather();
  }

  void _fitMarkersOnMap() {
    if (_stations.isEmpty) {
      return;
    }

    double minLat = _stations.values.first['lat'] as double;
    double maxLat = minLat;
    double minLng = _stations.values.first['lng'] as double;
    double maxLng = minLng;

    for (final Map<String, dynamic> station in _stations.values) {
      minLat = (station['lat'] as double) < minLat
          ? station['lat'] as double
          : minLat;
      maxLat = (station['lat'] as double) > maxLat
          ? station['lat'] as double
          : maxLat;
      minLng = (station['lng'] as double) < minLng
          ? station['lng'] as double
          : minLng;
      maxLng = (station['lng'] as double) > maxLng
          ? station['lng'] as double
          : maxLng;
    }

    final double centerLat = (minLat + maxLat) / 2;
    final double centerLng = (minLng + maxLng) / 2;

    setState(() {
      _currentPosition = latlong.LatLng(centerLat, centerLng);
    });
    _mapController.move(_currentPosition, 12.5);
  }

  String _formatDateTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  Color get _backgroundColor =>
      _isDarkTheme ? const Color(0xFF0F1A13) : const Color(0xFFF4F7F1);

  Color get _panelColor =>
      _isDarkTheme ? const Color(0xFF19261D) : Colors.white;

  Color get _weatherCardColor =>
      _isDarkTheme ? const Color(0xFF243528) : const Color(0xFFEEF5E9);

  Color get _primaryTextColor =>
      _isDarkTheme ? const Color(0xFFF4F7F1) : const Color(0xFF18341D);

  Color get _secondaryTextColor =>
      _isDarkTheme ? const Color(0xFF9FB5A1) : Colors.grey;

  Color get _cardAccent => const Color(0xFF49992E);

  Color get _labelTextColor =>
      _isDarkTheme ? const Color(0xFFC4D3C5) : const Color(0xFF6C7570);

  Color get _inputFillColor =>
      _isDarkTheme ? const Color(0xFF314437) : const Color(0xFFEEF5E9);

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime selectedForecastTime = now.add(
      Duration(hours: _selectedForecastHour),
    );
    final String? selectedStationName = _selectedStationId == null
        ? null
        : _stations[_selectedStationId]?['name'] as String?;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: _isDarkTheme ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _backgroundColor,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _panelColor,
          contentTextStyle: TextStyle(color: _primaryTextColor),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _cardAccent,
          foregroundColor: Colors.white,
          title: const Text(
            '은평 따릉이 예약',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          ],
        ),
        drawer: Drawer(
          backgroundColor: _panelColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF49992E)),
                child: const Text(
                  '메뉴',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.brightness_4, color: _primaryTextColor),
                title: Text('다크테마', style: TextStyle(color: _primaryTextColor)),
                trailing: Switch(
                  value: _isDarkTheme,
                  onChanged: (bool value) {
                    setState(() {
                      _isDarkTheme = value;
                    });
                    _persistTheme();
                  },
                ),
              ),
              if (_favoriteStationIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '즐겨찾기',
                    style: TextStyle(
                      color: _primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ..._favoriteStationIds.map((String stationId) {
                final Map<String, dynamic>? station = _stations[stationId];
                if (station == null) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.star, color: Color(0xFFFFC94A)),
                  title: Text(
                    station['name'] as String,
                    style: TextStyle(color: _primaryTextColor),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _focusStation(stationId);
                  },
                  trailing: IconButton(
                    onPressed: () => _removeFavorite(stationId),
                    icon: const Icon(Icons.close),
                  ),
                );
              }),
            ],
          ),
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition,
                initialZoom: 12.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'beangle_app',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _weatherCardColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _cardAccent.withValues(alpha: 0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: _cardAccent, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _weatherInfo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primaryTextColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isWeatherExpanded = !_isWeatherExpanded;
                            });
                          },
                          icon: Icon(
                            _isWeatherExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: _cardAccent,
                          ),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    if (_isWeatherExpanded) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            label: '온도',
                            value: _temperature,
                            accent: _cardAccent,
                            labelColor: _labelTextColor,
                            backgroundColor: _inputFillColor,
                          ),
                          _MetricChip(
                            label: '습도',
                            value: _humidity,
                            accent: _cardAccent,
                            labelColor: _labelTextColor,
                            backgroundColor: _inputFillColor,
                          ),
                          _MetricChip(
                            label: '강수량',
                            value: _precipitation,
                            accent: _cardAccent,
                            labelColor: _labelTextColor,
                            backgroundColor: _inputFillColor,
                          ),
                          _MetricChip(
                            label: '적설량',
                            value: _snowfall,
                            accent: _cardAccent,
                            labelColor: _labelTextColor,
                            backgroundColor: _inputFillColor,
                          ),
                          _MetricChip(
                            label: '불쾌지수',
                            value: _discomfortIndex,
                            accent: _cardAccent,
                            labelColor: _labelTextColor,
                            backgroundColor: _inputFillColor,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: _isWeatherExpanded ? 170 : 90,
              right: 14,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _isControlPanelExpanded ? 208 : 56,
                padding: EdgeInsets.symmetric(
                  horizontal: _isControlPanelExpanded ? 10 : 6,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _panelColor.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: _isControlPanelExpanded
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isControlPanelExpanded)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '예측 설정',
                              style: TextStyle(
                                color: _primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isControlPanelExpanded =
                                    !_isControlPanelExpanded;
                              });
                            },
                            icon: Icon(
                              Icons.keyboard_arrow_right,
                              color: _cardAccent,
                            ),
                            splashRadius: 18,
                          ),
                        ],
                      )
                    else
                      Tooltip(
                        message: '예측 설정 펼치기',
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isControlPanelExpanded = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _weatherCardColor.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cardAccent.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.keyboard_arrow_left,
                              color: _cardAccent,
                            ),
                          ),
                        ),
                      ),
                    if (_isControlPanelExpanded) ...[
                      TextButton.icon(
                        onPressed: _isWeatherLoading
                            ? null
                            : _resetToCurrentWeather,
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('현재 날씨'),
                        style: TextButton.styleFrom(
                          foregroundColor: _cardAccent,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _inputFillColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: _cardAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '현재 ${_formatDateTime(now)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _inputFillColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedForecastHour,
                          dropdownColor: _panelColor,
                          style: TextStyle(
                            color: _primaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          items: List<DropdownMenuItem<int>>.generate(8, (
                            int index,
                          ) {
                            final int hour = index + 1;
                            return DropdownMenuItem<int>(
                              value: hour,
                              child: Text(
                                '$hour시간 후',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryTextColor,
                                ),
                              ),
                            );
                          }),
                          onChanged: _isWeatherLoading
                              ? null
                              : _selectForecastHour,
                          isExpanded: true,
                          underline: const SizedBox(),
                          iconEnabledColor: _cardAccent,
                          iconDisabledColor: _secondaryTextColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isUsingCurrentWeather
                            ? '현재 실황 표시 중'
                            : '선택 시점 예보 (${_formatDateTime(selectedForecastTime)})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_stationStatus\n$_predictionStatus\n실시간 재고 + 학습 모델 예측 변동량 기준',
                        style: TextStyle(
                          fontSize: 11,
                          color: _secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_favoriteStationIds.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _favoriteStationIds.map((String stationId) {
                            final Map<String, dynamic>? station =
                                _stations[stationId];
                            if (station == null) {
                              return const SizedBox.shrink();
                            }
                            return ActionChip(
                              onPressed: () => _focusStation(stationId),
                              backgroundColor: _inputFillColor,
                              avatar: const Icon(
                                Icons.star,
                                size: 14,
                                color: Color(0xFFFFC94A),
                              ),
                              label: Text(
                                station['name'] as String,
                                style: TextStyle(color: _primaryTextColor),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 88,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _panelColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _cardAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bookmark_added, color: _cardAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedStationName ?? '선택된 스테이션 없음',
                            style: TextStyle(
                              color: _primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            selectedStationName == null
                                ? '마커를 눌러 예약 대상 스테이션을 선택하세요.'
                                : '$_selectedForecastHour시간 후 예약 1대 차감 적용',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isStationLoading ? null : _loadStations,
                      icon: Icon(Icons.refresh, color: _cardAccent),
                      tooltip: '새로고침',
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _reserveSelectedStation,
                icon: const Icon(Icons.check),
                label: const Text('예약하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherSnapshot {
  const _WeatherSnapshot({
    required this.summary,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.snowfall,
  });

  final String summary;
  final double temperature;
  final int humidity;
  final double precipitation;
  final double snowfall;
}

class _StationAvailability {
  const _StationAvailability({
    required this.name,
    required this.available,
    required this.parking,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final int available;
  final int parking;
  final double latitude;
  final double longitude;
}

class _ForecastOffsetSummary {
  const _ForecastOffsetSummary({
    required this.inflow,
    required this.outflow,
    required this.netFlow,
    required this.targetTime,
  });

  final double inflow;
  final double outflow;
  final double netFlow;
  final DateTime? targetTime;
}

class _StationMarkerChip extends StatelessWidget {
  const _StationMarkerChip({
    required this.stationName,
    required this.currentAvailable,
    required this.predictedAvailable,
    required this.color,
    required this.isFavorite,
    required this.isSelected,
  });

  final String stationName;
  final int currentAvailable;
  final int predictedAvailable;
  final Color color;
  final bool isFavorite;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '$stationName  현 $currentAvailable / 예 $predictedAvailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: isSelected ? 48 : 42,
          height: isSelected ? 48 : 42,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: isSelected ? 0.34 : 0.26),
                color.withValues(alpha: 0.06),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: isSelected ? 0.9 : 0.55),
              width: isSelected ? 2.4 : 1.6,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.pedal_bike, color: color, size: isSelected ? 24 : 22),
              if (isFavorite)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.star, color: Color(0xFFFFC94A), size: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.accent,
    required this.labelColor,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final Color accent;
  final Color labelColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color resolvedLabelColor =
        labelColor ??
        (isDark ? const Color(0xFFC4D3C5) : const Color(0xFF6C7570));
    final Color resolvedValueColor =
        valueColor ??
        (isDark ? const Color(0xFFF4F7F1) : const Color(0xFF18341D));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: resolvedLabelColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: resolvedValueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
