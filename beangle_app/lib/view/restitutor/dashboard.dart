// ===============================================
// File: dashboard.dart
// Purpose: Reservation cycle table page
//
// Change Log
// - 23-Mar-2026, Codex
//   - Simplified the page to a centered Excel-style table.
//   - Aligned the column mapping with the stationCode + cycle availability data.
// ===============================================
import 'dart:convert';

import 'package:beangle_app/app_shell.dart';
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

  late final Future<List<_ReservationCycleRow>> _reservationCycleFuture;

  @override
  void initState() {
    super.initState();
    _reservationCycleFuture = _loadReservationCycleRows();
  }

  Future<List<_ReservationCycleRow>> _loadReservationCycleRows() async {
    final Map<String, dynamic> predictionData = await _loadPredictionData();
    final Map<String, Map<int, int>> reservedCounts = _decodeReservedCounts(
      _storage.read<Map<dynamic, dynamic>>(_reservationStorageKey),
    );

    return Future.wait(
      _stationSeeds.map(
        (_StationSeed seed) async => _buildReservationCycleRow(
          seed: seed,
          predictionData: predictionData,
          reservedCounts: reservedCounts,
        ),
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

  Future<_ReservationCycleRow> _buildReservationCycleRow({
    required _StationSeed seed,
    required Map<String, dynamic> predictionData,
    required Map<String, Map<int, int>> reservedCounts,
  }) async {
    final _StationAvailabilitySnapshot station =
        await _fetchStationAvailability(seed);
    final int currentAvailableCycleCount = station.available;
    final int rackCount = station.available + station.parking;

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
      border: TableBorder.all(color: const Color(0xFFD2D7DE), width: 1),
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
      color: const Color(0xFFF3F5F7),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _buildStationCell(String stationCode) {
    return Container(
      height: 50,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFF9FAFB),
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
      color: Colors.white,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF111827)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Reservation Cycle Table',
      currentRoute: AppRoutes.dashboard,
      body: FutureBuilder<List<_ReservationCycleRow>>(
        future: _reservationCycleFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<_ReservationCycleRow>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Reservation cycle data could not be loaded.'),
                );
              }

              final List<_ReservationCycleRow> rows =
                  snapshot.data ?? const <_ReservationCycleRow>[];

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildReservationCycleTable(rows),
                      ),
                    ),
                  ),
                ),
              );
            },
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
  ),
  availableCycleCountAfter1Hour(
    excelHeader: 'available_cycle_count_after_1_hour',
    label: '+1h',
  ),
  availableCycleCountAfter2Hours(
    excelHeader: 'available_cycle_count_after_2_hours',
    label: '+2h',
  ),
  availableCycleCountAfter3Hours(
    excelHeader: 'available_cycle_count_after_3_hours',
    label: '+3h',
  ),
  availableCycleCountAfter4Hours(
    excelHeader: 'available_cycle_count_after_4_hours',
    label: '+4h',
  ),
  availableCycleCountAfter5Hours(
    excelHeader: 'available_cycle_count_after_5_hours',
    label: '+5h',
  ),
  availableCycleCountAfter6Hours(
    excelHeader: 'available_cycle_count_after_6_hours',
    label: '+6h',
  ),
  availableCycleCountAfter7Hours(
    excelHeader: 'available_cycle_count_after_7_hours',
    label: '+7h',
  ),
  availableCycleCountAfter8Hours(
    excelHeader: 'available_cycle_count_after_8_hours',
    label: '+8h',
  );

  const _ReservationCycleColumn({
    required this.excelHeader,
    required this.label,
  });

  final String excelHeader;
  final String label;
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
