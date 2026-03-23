// ===============================================
// Creator: Chansol, Park
// File: dashboard.dart
// Purpose: Reservation cycle table page
//
// Change Log
// - 23-Mar-2026, Codex
//   - Simplified the page to a centered Excel-style table.
//   - Aligned the column mapping with the stationCode + cycle availability data.
// - 23-Mar-2026, Codex
//   - Added station selection and a selected-station chart view with fl_chart.
// - 23-Mar-2026, Codex
//   - Fixed reservation synchronization for the current reservation state flow.
//   - Added station-filtered refill logs from the Python API.
// - 23-Mar-2026, Codex
//   - Reworked the dashboard to adapt to the current reservation/backend files
//     without changing other existing files.
//   - Kept refill log loading as a dashboard-side best-effort integration.
// ===============================================
import 'dart:convert';

import 'package:beangle_app/auth/auth_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class StationExcelPage extends StatefulWidget {
  const StationExcelPage({super.key});

  @override
  State<StationExcelPage> createState() => _StationExcelPageState();
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

abstract class _ReservationCycleTableState<T extends StatefulWidget>
    extends State<T> {
  static const String _bikeApiKey = '595975485377617236307a746f5179';
  static const String _predictionAssetPath =
      'assets/data/station_hourly_predictions.json';
  static const String _reservationStorageKey = 'station_reservations';
  static const String _workerIdStorageKey = 'worker_id';

  static const Color _primaryColor = Color(0xFF49992E);
  static const Color _pageBackgroundColor = Color(0xFFF5F8F1);
  static const Color _headerTextColor = Colors.white;
  static const Color _tableBorderColor = Color(0xFF91B184);
  static const Color _stationColumnColor = Color(0xFFE8F2E1);
  static const Color _valueCellColor = Colors.white;

  static const double _stationColumnWidth = 132;
  static const double _dataColumnWidth = 118;

  static const List<_StationSeed> _stationSeeds = <_StationSeed>[
    _StationSeed(
      stationCode: 'ST-481',
      stationNumber: 933,
      fallbackAvailable: 9,
      fallbackParking: 6,
    ),
    _StationSeed(
      stationCode: 'ST-2425',
      stationNumber: 4652,
      fallbackAvailable: 0,
      fallbackParking: 0,
    ),
    _StationSeed(
      stationCode: 'ST-1331',
      stationNumber: 956,
      fallbackAvailable: 10,
      fallbackParking: 8,
    ),
    _StationSeed(
      stationCode: 'ST-454',
      stationNumber: 906,
      fallbackAvailable: 5,
      fallbackParking: 4,
    ),
    _StationSeed(
      stationCode: 'ST-453',
      stationNumber: 905,
      fallbackAvailable: 11,
      fallbackParking: 9,
    ),
  ];

  final GetStorage _storage = GetStorage();

  VoidCallback? _cancelReservationStorageListener;
  Map<String, dynamic> _predictionData = const <String, dynamic>{};
  Map<String, _StationAvailabilitySnapshot> _stationAvailabilityByCode =
      const <String, _StationAvailabilitySnapshot>{};
  List<_ReservationCycleRow> _reservationCycleRows =
      const <_ReservationCycleRow>[];
  List<_RefillLogItem> _refillLogs = const <_RefillLogItem>[];
  String? _selectedStationCode;
  String? _refillLogErrorText;
  bool _isLoading = true;
  bool _isRefillLogLoading = false;
  int _refillLogRequestToken = 0;

  @override
  void initState() {
    super.initState();

    // The dashboard reacts to the shared reservation storage already used by
    // the current user-side reservation flow, so table and chart data rebuild
    // automatically without changing the existing reservation files.
    _cancelReservationStorageListener = _storage.listenKey(
      _reservationStorageKey,
      (_) => _rebuildReservationCycleRows(),
    );

    _initializeReservationCycleTable();
  }

  @override
  void dispose() {
    _cancelReservationStorageListener?.call();
    super.dispose();
  }

  String get _pythonApiBaseUrl {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://10.0.2.2:8000';
  }

  Future<void> _logout() async {
    await _storage.remove(_workerIdStorageKey);
    if (!mounted) {
      return;
    }
    Get.offAll(() => const AuthPage());
  }

  Future<void> _initializeReservationCycleTable() async {
    final Map<String, dynamic> predictionData = await _loadPredictionData();
    final Map<String, _StationAvailabilitySnapshot> stationAvailabilityByCode =
        await _loadStationAvailabilityByCode();
    final String? selectedStationCode = _resolveSelectedStationCode(
      _reservationCycleRows,
    );
    final List<_ReservationCycleRow> reservationCycleRows =
        _buildReservationCycleRows(
          predictionData: predictionData,
          stationAvailabilityByCode: stationAvailabilityByCode,
          reservedTimes: _decodeReservedTimes(
            _storage.read<Map<dynamic, dynamic>>(_reservationStorageKey),
          ),
        );
    final String? resolvedSelectedStationCode = _resolveSelectedStationCode(
      reservationCycleRows,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _predictionData = predictionData;
      _stationAvailabilityByCode = stationAvailabilityByCode;
      _reservationCycleRows = reservationCycleRows;
      _selectedStationCode = resolvedSelectedStationCode ?? selectedStationCode;
      _isLoading = false;
    });

    await _loadRefillLogsForSelectedStation();
  }

  Future<Map<String, _StationAvailabilitySnapshot>>
  _loadStationAvailabilityByCode() async {
    final List<MapEntry<String, _StationAvailabilitySnapshot>> stationEntries =
        await Future.wait(
          _stationSeeds.map((_StationSeed seed) async {
            return MapEntry<String, _StationAvailabilitySnapshot>(
              seed.stationCode,
              await _fetchStationAvailability(seed),
            );
          }),
        );

    return <String, _StationAvailabilitySnapshot>{
      for (final MapEntry<String, _StationAvailabilitySnapshot> entry
          in stationEntries)
        entry.key: entry.value,
    };
  }

  void _rebuildReservationCycleRows() {
    if (_isLoading || _stationAvailabilityByCode.isEmpty) {
      return;
    }

    final List<_ReservationCycleRow> reservationCycleRows =
        _buildReservationCycleRows(
          predictionData: _predictionData,
          stationAvailabilityByCode: _stationAvailabilityByCode,
          reservedTimes: _decodeReservedTimes(
            _storage.read<Map<dynamic, dynamic>>(_reservationStorageKey),
          ),
        );
    final String? nextSelectedStationCode = _resolveSelectedStationCode(
      reservationCycleRows,
    );
    final bool didSelectedStationChange =
        nextSelectedStationCode != _selectedStationCode;

    if (!mounted) {
      return;
    }

    setState(() {
      _reservationCycleRows = reservationCycleRows;
      _selectedStationCode = nextSelectedStationCode;
    });

    if (didSelectedStationChange) {
      _loadRefillLogsForSelectedStation();
    }
  }

  String? _resolveSelectedStationCode(List<_ReservationCycleRow> rows) {
    if (rows.isEmpty) {
      return null;
    }

    final String? selectedStationCode = _selectedStationCode;
    if (selectedStationCode != null &&
        rows.any(
          (_ReservationCycleRow row) => row.stationCode == selectedStationCode,
        )) {
      return selectedStationCode;
    }

    return rows.first.stationCode;
  }

  _ReservationCycleRow? get _selectedReservationCycleRow {
    final String? selectedStationCode = _selectedStationCode;
    if (selectedStationCode == null) {
      return _reservationCycleRows.isEmpty ? null : _reservationCycleRows.first;
    }

    for (final _ReservationCycleRow row in _reservationCycleRows) {
      if (row.stationCode == selectedStationCode) {
        return row;
      }
    }

    return _reservationCycleRows.isEmpty ? null : _reservationCycleRows.first;
  }

  _StationSeed? get _selectedStationSeed {
    final String? selectedStationCode = _selectedStationCode;
    if (selectedStationCode == null) {
      return null;
    }

    for (final _StationSeed seed in _stationSeeds) {
      if (seed.stationCode == selectedStationCode) {
        return seed;
      }
    }

    return null;
  }

  List<_ReservationCycleRow> _buildReservationCycleRows({
    required Map<String, dynamic> predictionData,
    required Map<String, _StationAvailabilitySnapshot>
    stationAvailabilityByCode,
    required Map<String, List<DateTime>> reservedTimes,
  }) {
    return _stationSeeds
        .map((_StationSeed seed) {
          return _buildReservationCycleRow(
            seed: seed,
            predictionData: predictionData,
            stationAvailability:
                stationAvailabilityByCode[seed.stationCode] ??
                seed.toSnapshot(),
            reservedTimes: reservedTimes,
          );
        })
        .toList(growable: false);
  }

  _ReservationCycleRow _buildReservationCycleRow({
    required _StationSeed seed,
    required Map<String, dynamic> predictionData,
    required _StationAvailabilitySnapshot stationAvailability,
    required Map<String, List<DateTime>> reservedTimes,
  }) {
    final int currentAvailableCycleCount = stationAvailability.available;
    final int rackCount =
        stationAvailability.available + stationAvailability.parking;

    return _ReservationCycleRow(
      stationCode: seed.stationCode,
      currentAvailableCycleCount: currentAvailableCycleCount,
      availableCycleCountAfter1Hour: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 1,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter2Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 2,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter3Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 3,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter4Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 4,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter5Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 5,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter6Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 6,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter7Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 7,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
      availableCycleCountAfter8Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 8,
        predictionData: predictionData,
        reservedTimes: reservedTimes,
      ),
    );
  }

  Future<Map<String, dynamic>> _loadPredictionData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        _predictionAssetPath,
      );
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  String? _normalizeStationCode(dynamic stationKey) {
    final String rawStationKey = stationKey.toString();

    for (final _StationSeed seed in _stationSeeds) {
      if (seed.stationCode == rawStationKey ||
          seed.stationNumber.toString() == rawStationKey) {
        return seed.stationCode;
      }
    }

    return null;
  }

  Map<String, List<DateTime>> _decodeReservedTimes(Map<dynamic, dynamic>? raw) {
    final Map<String, List<DateTime>> decoded = <String, List<DateTime>>{};
    if (raw == null) {
      return decoded;
    }

    raw.forEach((dynamic stationKey, dynamic value) {
      final String? stationCode = _normalizeStationCode(stationKey);
      if (stationCode == null) {
        return;
      }

      final List<DateTime> stationReservations = <DateTime>[];

      if (value is List) {
        for (final dynamic item in value) {
          final DateTime? parsedTime = DateTime.tryParse(item.toString());
          if (parsedTime != null) {
            stationReservations.add(parsedTime);
          }
        }
      } else if (value is Map) {
        value.forEach((dynamic hour, dynamic count) {
          final int? parsedHour = int.tryParse(hour.toString());
          final int? parsedCount = int.tryParse(count.toString());
          if (parsedHour == null || parsedCount == null || parsedCount <= 0) {
            return;
          }

          for (int index = 0; index < parsedCount; index++) {
            stationReservations.add(
              DateTime.now().add(Duration(hours: parsedHour)),
            );
          }
        });
      } else {
        return;
      }

      stationReservations.sort();
      if (stationReservations.isEmpty) {
        return;
      }

      final List<DateTime> mergedReservations = decoded.putIfAbsent(
        stationCode,
        () => <DateTime>[],
      );
      for (final DateTime reservationTime in stationReservations) {
        if (!mergedReservations.any(
          (DateTime value) => value.isAtSameMomentAs(reservationTime),
        )) {
          mergedReservations.add(reservationTime);
        }
      }
      mergedReservations.sort();
    });

    return decoded;
  }

  Future<void> _loadRefillLogsForSelectedStation() async {
    final _StationSeed? selectedStationSeed = _selectedStationSeed;
    if (selectedStationSeed == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _refillLogs = const <_RefillLogItem>[];
        _refillLogErrorText = null;
        _isRefillLogLoading = false;
      });
      return;
    }

    final int requestToken = ++_refillLogRequestToken;
    if (mounted) {
      setState(() {
        _isRefillLogLoading = true;
        _refillLogErrorText = null;
      });
    }

    final Uri uri = Uri.parse('$_pythonApiBaseUrl/refill-logs').replace(
      queryParameters: <String, String>{
        'station_code': selectedStationSeed.stationCode,
        'station_number': selectedStationSeed.stationNumber.toString(),
      },
    );

    try {
      final http.Response response = await http.get(uri);
      if (requestToken != _refillLogRequestToken || !mounted) {
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _isRefillLogLoading = false;
          _refillLogErrorText = response.statusCode == 404
              ? 'Refill logs are not exposed by the current Python API.'
              : 'Refill logs could not be loaded.';
        });
        return;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawLogs =
          json['logs'] as List<dynamic>? ?? <dynamic>[];
      final List<_RefillLogItem> refillLogs =
          rawLogs
              .map(
                (dynamic item) =>
                    _RefillLogItem.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false)
            ..sort(
              (_RefillLogItem a, _RefillLogItem b) =>
                  b.refillTime.compareTo(a.refillTime),
            );

      setState(() {
        _isRefillLogLoading = false;
        _refillLogs = refillLogs;
      });
    } catch (_) {
      if (requestToken != _refillLogRequestToken || !mounted) {
        return;
      }

      setState(() {
        _isRefillLogLoading = false;
        _refillLogErrorText =
            'Refill logs could not be loaded from the current Python API.';
      });
    }
  }

  Future<_StationAvailabilitySnapshot> _fetchStationAvailability(
    _StationSeed seed,
  ) async {
    final Uri uri = Uri.parse(
      'http://openapi.seoul.go.kr:8088/$_bikeApiKey/json/bikeList/1/1/${seed.stationCode}',
    );

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        return seed.toSnapshot();
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic>? bikeStatus =
          decoded['rentBikeStatus'] as Map<String, dynamic>?;
      final List<dynamic>? rows = bikeStatus?['row'] as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        return seed.toSnapshot();
      }

      final Map<String, dynamic> row = rows.first as Map<String, dynamic>;
      final int available =
          int.tryParse(row['parkingBikeTotCnt']?.toString() ?? '') ??
          seed.fallbackAvailable;
      final int rackCount =
          int.tryParse(row['rackTotCnt']?.toString() ?? '') ??
          (seed.fallbackAvailable + seed.fallbackParking);

      return _StationAvailabilitySnapshot(
        available: available,
        parking: (rackCount - available).clamp(0, rackCount),
      );
    } catch (_) {
      return seed.toSnapshot();
    }
  }

  int _calculateAvailableCycleCount({
    required String stationCode,
    required int currentAvailableCycleCount,
    required int rackCount,
    required int offsetHour,
    required Map<String, dynamic> predictionData,
    required Map<String, List<DateTime>> reservedTimes,
  }) {
    final double predictedNetFlow = _lookupPredictedNetFlow(
      stationCode: stationCode,
      offsetHour: offsetHour,
      predictionData: predictionData,
    );
    final int reservationImpact = _cumulativeReservedCount(
      stationCode: stationCode,
      hour: offsetHour,
      reservedTimes: reservedTimes,
    );
    final int predicted =
        (currentAvailableCycleCount + predictedNetFlow).round() -
        reservationImpact;

    return predicted.clamp(0, rackCount);
  }

  double _lookupPredictedNetFlow({
    required String stationCode,
    required int offsetHour,
    required Map<String, dynamic> predictionData,
  }) {
    final DateTime now = DateTime.now();
    final Map<String, dynamic>? stationMap =
        predictionData[stationCode] as Map<String, dynamic>?;
    final Map<String, dynamic>? slotMap =
        stationMap?['slots'] as Map<String, dynamic>?;
    final Map<String, dynamic>? monthMap =
        slotMap?['${now.month}'] as Map<String, dynamic>?;
    final Map<String, dynamic>? weekdayMap =
        monthMap?['${now.weekday - 1}'] as Map<String, dynamic>?;
    final Map<String, dynamic>? baseHourMap =
        weekdayMap?['${now.hour}'] as Map<String, dynamic>?;
    final Map<String, dynamic>? offsets =
        baseHourMap?['offsets'] as Map<String, dynamic>?;
    final Map<String, dynamic>? selectedOffset =
        offsets?['$offsetHour'] as Map<String, dynamic>?;

    return (selectedOffset?['net_flow'] as num?)?.toDouble() ?? 0;
  }

  int _cumulativeReservedCount({
    required String stationCode,
    required int hour,
    required Map<String, List<DateTime>> reservedTimes,
  }) {
    final List<DateTime> stationReservations =
        reservedTimes[stationCode] ?? <DateTime>[];
    final DateTime now = DateTime.now();
    final DateTime targetTime = now.add(Duration(hours: hour));

    return stationReservations.where((DateTime reservationTime) {
      return reservationTime.isAfter(now) &&
          !reservationTime.isAfter(targetTime);
    }).length;
  }

  Table _buildReservationCycleTable(List<_ReservationCycleRow> rows) {
    final Map<int, TableColumnWidth> columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(_stationColumnWidth),
    };

    for (
      int index = 0;
      index < _ReservationCycleColumn.values.length;
      index++
    ) {
      columnWidths[index + 1] = const FixedColumnWidth(_dataColumnWidth);
    }

    return Table(
      border: TableBorder.all(color: _tableBorderColor, width: 1.2),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            _buildHeaderCell('Station Code'),
            ..._ReservationCycleColumn.values.map(
              (_ReservationCycleColumn column) =>
                  _buildHeaderCell(column.label),
            ),
          ],
        ),
        ...rows.map(
          (_ReservationCycleRow row) => TableRow(
            children: <Widget>[
              _buildStationCell(row.stationCode),
              ..._ReservationCycleColumn.values.map(
                (_ReservationCycleColumn column) =>
                    _buildValueCell(row.valueFor(column)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String label) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _primaryColor,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _headerTextColor,
        ),
      ),
    );
  }

  Widget _buildStationCell(String stationCode) {
    return Container(
      height: 50,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _stationColumnColor,
      child: Text(
        stationCode,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildValueCell(int value) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _valueCellColor,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStationDropdown() {
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String?>(_selectedStationCode),
        initialValue: _selectedStationCode,
        decoration: InputDecoration(
          labelText: 'Station',
          labelStyle: const TextStyle(
            color: Color(0xFF355F25),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _tableBorderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _tableBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 1.6),
          ),
        ),
        items: _reservationCycleRows
            .map(
              (_ReservationCycleRow row) => DropdownMenuItem<String>(
                value: row.stationCode,
                child: Text(row.stationCode),
              ),
            )
            .toList(growable: false),
        onChanged: (String? stationCode) {
          if (stationCode == null) {
            return;
          }

          setState(() {
            _selectedStationCode = stationCode;
          });

          _loadRefillLogsForSelectedStation();
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF26481A),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSectionFrame({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _tableBorderColor, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }

  Widget _buildStationTrendChart(_ReservationCycleRow row) {
    // The chart uses the same ordered reservation cycle columns as the table so
    // the selected station shows one consistent data story in both views.
    final List<_ChartPoint> chartPoints = _ReservationCycleColumn.values
        .map(
          (_ReservationCycleColumn column) => _ChartPoint(
            label: column.chartLabel,
            value: row.valueFor(column),
          ),
        )
        .toList(growable: false);
    final int maxValue = chartPoints.fold<int>(
      0,
      (int currentMax, _ChartPoint point) =>
          point.value > currentMax ? point.value : currentMax,
    );
    final double maxY = (maxValue <= 0 ? 1 : maxValue + 2).toDouble();
    final double interval = maxY <= 4 ? 1 : (maxY / 4).ceilToDouble();

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (chartPoints.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (double value) {
                return const FlLine(color: Color(0xFFE0E6DA), strokeWidth: 1);
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: _tableBorderColor, width: 1),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                isCurved: false,
                color: _primaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter:
                      (
                        FlSpot spot,
                        double percent,
                        LineChartBarData bar,
                        int index,
                      ) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _primaryColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                ),
                belowBarData: BarAreaData(show: false),
                spots: List<FlSpot>.generate(
                  chartPoints.length,
                  (int index) => FlSpot(
                    index.toDouble(),
                    chartPoints[index].value.toDouble(),
                  ),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= chartPoints.length) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      meta: meta,
                      space: 10,
                      child: Text(
                        chartPoints[index].label,
                        style: const TextStyle(
                          color: Color(0xFF37522B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: interval,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Color(0xFF37522B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRefillTime(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  Widget _buildRefillLogSection() {
    if (_isRefillLogLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_refillLogErrorText != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _refillLogErrorText!,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_refillLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No refill logs for the selected station.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: _refillLogs
            .map((_RefillLogItem log) {
              final String workerSummary = <String>[
                if (log.workerName != null && log.workerName!.isNotEmpty)
                  log.workerName!,
                if (log.workerPhone != null && log.workerPhone!.isNotEmpty)
                  log.workerPhone!,
                if (log.workerRole != null && log.workerRole!.isNotEmpty)
                  log.workerRole!,
              ].join(' · ');

              return Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _stationColumnColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _primaryColor,
                      ),
                    ),
                    title: Text(
                      _formatRefillTime(log.refillTime),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        workerSummary.isEmpty
                            ? 'Worker information unavailable'
                            : workerSummary,
                        style: const TextStyle(color: Color(0xFF4B5563)),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (log.refillCount != null)
                          Text(
                            '+${log.refillCount} cycles',
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (log.workerId != null)
                          Text(
                            'Worker #${log.workerId}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (log != _refillLogs.last)
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ReservationCycleRow? selectedReservationCycleRow =
        _selectedReservationCycleRow;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FBF4),
        foregroundColor: const Color(0xFF1F3516),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _logout,
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ColoredBox(
        color: _pageBackgroundColor,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: _primaryColor)
              : selectedReservationCycleRow == null
              ? const Text('No station data available.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildStationDropdown(),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Cycle Table'),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSectionFrame(
                              child: _buildReservationCycleTable(
                                <_ReservationCycleRow>[
                                  selectedReservationCycleRow,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Availability Trend'),
                          const SizedBox(height: 10),
                          _buildSectionFrame(
                            child: _buildStationTrendChart(
                              selectedReservationCycleRow,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Refill Logs'),
                          const SizedBox(height: 10),
                          _buildSectionFrame(child: _buildRefillLogSection()),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StationExcelPageState
    extends _ReservationCycleTableState<StationExcelPage> {}

class _DashboardState extends _ReservationCycleTableState<Dashboard> {}

class _StationSeed {
  const _StationSeed({
    required this.stationCode,
    required this.stationNumber,
    required this.fallbackAvailable,
    required this.fallbackParking,
  });

  final String stationCode;
  final int stationNumber;
  final int fallbackAvailable;
  final int fallbackParking;

  _StationAvailabilitySnapshot toSnapshot() {
    return _StationAvailabilitySnapshot(
      available: fallbackAvailable,
      parking: fallbackParking,
    );
  }
}

class _StationAvailabilitySnapshot {
  const _StationAvailabilitySnapshot({
    required this.available,
    required this.parking,
  });

  final int available;
  final int parking;
}

// These Excel headers now map directly to the reservation cycle fields used
// by this page so only the current and +1h to +8h cycle counts are rendered.
enum _ReservationCycleColumn {
  currentAvailableCycleCount(
    excelHeader: 'current_available_cycle_count',
    label: 'Current',
    chartLabel: 'Now',
  ),
  availableCycleCountAfter1Hour(
    excelHeader: 'available_cycle_count_after_1_hour',
    label: '+1h',
    chartLabel: '1h',
  ),
  availableCycleCountAfter2Hours(
    excelHeader: 'available_cycle_count_after_2_hours',
    label: '+2h',
    chartLabel: '2h',
  ),
  availableCycleCountAfter3Hours(
    excelHeader: 'available_cycle_count_after_3_hours',
    label: '+3h',
    chartLabel: '3h',
  ),
  availableCycleCountAfter4Hours(
    excelHeader: 'available_cycle_count_after_4_hours',
    label: '+4h',
    chartLabel: '4h',
  ),
  availableCycleCountAfter5Hours(
    excelHeader: 'available_cycle_count_after_5_hours',
    label: '+5h',
    chartLabel: '5h',
  ),
  availableCycleCountAfter6Hours(
    excelHeader: 'available_cycle_count_after_6_hours',
    label: '+6h',
    chartLabel: '6h',
  ),
  availableCycleCountAfter7Hours(
    excelHeader: 'available_cycle_count_after_7_hours',
    label: '+7h',
    chartLabel: '7h',
  ),
  availableCycleCountAfter8Hours(
    excelHeader: 'available_cycle_count_after_8_hours',
    label: '+8h',
    chartLabel: '8h',
  );

  const _ReservationCycleColumn({
    required this.excelHeader,
    required this.label,
    required this.chartLabel,
  });

  final String excelHeader;
  final String label;
  final String chartLabel;
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});

  final String label;
  final int value;
}

class _RefillLogItem {
  const _RefillLogItem({
    required this.refillTime,
    this.refillCount,
    this.workerId,
    this.workerName,
    this.workerPhone,
    this.workerRole,
  });

  final DateTime refillTime;
  final int? refillCount;
  final int? workerId;
  final String? workerName;
  final String? workerPhone;
  final String? workerRole;

  factory _RefillLogItem.fromJson(Map<String, dynamic> json) {
    return _RefillLogItem(
      refillTime:
          DateTime.tryParse(json['refill_time']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      refillCount: int.tryParse(json['refill_count']?.toString() ?? ''),
      workerId: int.tryParse(json['worker_id']?.toString() ?? ''),
      workerName: json['worker_name']?.toString(),
      workerPhone: json['worker_phone']?.toString(),
      workerRole: json['worker_role']?.toString(),
    );
  }
}

class _ReservationCycleRow {
  const _ReservationCycleRow({
    required this.stationCode,
    required this.currentAvailableCycleCount,
    required this.availableCycleCountAfter1Hour,
    required this.availableCycleCountAfter2Hours,
    required this.availableCycleCountAfter3Hours,
    required this.availableCycleCountAfter4Hours,
    required this.availableCycleCountAfter5Hours,
    required this.availableCycleCountAfter6Hours,
    required this.availableCycleCountAfter7Hours,
    required this.availableCycleCountAfter8Hours,
  });

  final String stationCode;
  final int currentAvailableCycleCount;
  final int availableCycleCountAfter1Hour;
  final int availableCycleCountAfter2Hours;
  final int availableCycleCountAfter3Hours;
  final int availableCycleCountAfter4Hours;
  final int availableCycleCountAfter5Hours;
  final int availableCycleCountAfter6Hours;
  final int availableCycleCountAfter7Hours;
  final int availableCycleCountAfter8Hours;

  int valueFor(_ReservationCycleColumn column) {
    switch (column) {
      case _ReservationCycleColumn.currentAvailableCycleCount:
        return currentAvailableCycleCount;
      case _ReservationCycleColumn.availableCycleCountAfter1Hour:
        return availableCycleCountAfter1Hour;
      case _ReservationCycleColumn.availableCycleCountAfter2Hours:
        return availableCycleCountAfter2Hours;
      case _ReservationCycleColumn.availableCycleCountAfter3Hours:
        return availableCycleCountAfter3Hours;
      case _ReservationCycleColumn.availableCycleCountAfter4Hours:
        return availableCycleCountAfter4Hours;
      case _ReservationCycleColumn.availableCycleCountAfter5Hours:
        return availableCycleCountAfter5Hours;
      case _ReservationCycleColumn.availableCycleCountAfter6Hours:
        return availableCycleCountAfter6Hours;
      case _ReservationCycleColumn.availableCycleCountAfter7Hours:
        return availableCycleCountAfter7Hours;
      case _ReservationCycleColumn.availableCycleCountAfter8Hours:
        return availableCycleCountAfter8Hours;
    }
  }
}
