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
// ===============================================
import 'dart:convert';

import 'package:beangle_app/app_shell.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      fallbackAvailable: 9,
      fallbackParking: 6,
    ),
    _StationSeed(
      stationCode: 'ST-2425',
      fallbackAvailable: 0,
      fallbackParking: 0,
    ),
    _StationSeed(
      stationCode: 'ST-1331',
      fallbackAvailable: 10,
      fallbackParking: 8,
    ),
    _StationSeed(
      stationCode: 'ST-454',
      fallbackAvailable: 5,
      fallbackParking: 4,
    ),
    _StationSeed(
      stationCode: 'ST-453',
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
  String? _selectedStationCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // The dashboard listens to the same reservation storage key that drives
    // the cycle forecast logic so reservation create/cancel writes rebuild the
    // table without any manual refresh.
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

  Future<void> _initializeReservationCycleTable() async {
    final Map<String, dynamic> predictionData = await _loadPredictionData();
    final Map<String, _StationAvailabilitySnapshot> stationAvailabilityByCode =
        await _loadStationAvailabilityByCode();
    final List<_ReservationCycleRow> reservationCycleRows =
        _buildReservationCycleRows(
          predictionData: predictionData,
          stationAvailabilityByCode: stationAvailabilityByCode,
          reservedCounts: _decodeReservedCounts(
            _storage.read<Map<dynamic, dynamic>>(_reservationStorageKey),
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _predictionData = predictionData;
      _stationAvailabilityByCode = stationAvailabilityByCode;
      _reservationCycleRows = reservationCycleRows;
      _selectedStationCode = _resolveSelectedStationCode(reservationCycleRows);
      _isLoading = false;
    });
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
          reservedCounts: _decodeReservedCounts(
            _storage.read<Map<dynamic, dynamic>>(_reservationStorageKey),
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _reservationCycleRows = reservationCycleRows;
      _selectedStationCode = _resolveSelectedStationCode(reservationCycleRows);
    });
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

  List<_ReservationCycleRow> _buildReservationCycleRows({
    required Map<String, dynamic> predictionData,
    required Map<String, _StationAvailabilitySnapshot>
    stationAvailabilityByCode,
    required Map<String, Map<int, int>> reservedCounts,
  }) {
    return _stationSeeds
        .map((_StationSeed seed) {
          return _buildReservationCycleRow(
            seed: seed,
            predictionData: predictionData,
            stationAvailability:
                stationAvailabilityByCode[seed.stationCode] ??
                seed.toSnapshot(),
            reservedCounts: reservedCounts,
          );
        })
        .toList(growable: false);
  }

  _ReservationCycleRow _buildReservationCycleRow({
    required _StationSeed seed,
    required Map<String, dynamic> predictionData,
    required _StationAvailabilitySnapshot stationAvailability,
    required Map<String, Map<int, int>> reservedCounts,
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
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter2Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 2,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter3Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 3,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter4Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 4,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter5Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 5,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter6Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 6,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter7Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 7,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
      ),
      availableCycleCountAfter8Hours: _calculateAvailableCycleCount(
        stationCode: seed.stationCode,
        currentAvailableCycleCount: currentAvailableCycleCount,
        rackCount: rackCount,
        offsetHour: 8,
        predictionData: predictionData,
        reservedCounts: reservedCounts,
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

  Map<String, Map<int, int>> _decodeReservedCounts(Map<dynamic, dynamic>? raw) {
    final Map<String, Map<int, int>> decoded = <String, Map<int, int>>{};
    if (raw == null) {
      return decoded;
    }

    raw.forEach((dynamic stationCode, dynamic offsetMap) {
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
        decoded[stationCode.toString()] = stationReservations;
      }
    });

    return decoded;
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
    required Map<String, Map<int, int>> reservedCounts,
  }) {
    final double predictedNetFlow = _lookupPredictedNetFlow(
      stationCode: stationCode,
      offsetHour: offsetHour,
      predictionData: predictionData,
    );
    final int reservationImpact = _cumulativeReservedCount(
      stationCode: stationCode,
      hour: offsetHour,
      reservedCounts: reservedCounts,
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
    required Map<String, Map<int, int>> reservedCounts,
  }) {
    final Map<int, int> stationReservations =
        reservedCounts[stationCode] ?? <int, int>{};
    int total = 0;

    stationReservations.forEach((int offsetHour, int count) {
      if (offsetHour <= hour) {
        total += count;
      }
    });

    return total;
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

  @override
  Widget build(BuildContext context) {
    final _ReservationCycleRow? selectedReservationCycleRow =
        _selectedReservationCycleRow;

    return AppPageScaffold(
      title: 'Reservation Cycle Table',
      currentRoute: AppRoutes.dashboard,
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
    required this.fallbackAvailable,
    required this.fallbackParking,
  });

  final String stationCode;
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
