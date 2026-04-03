import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Platform configuration reminder: key=API_KEY

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StationMapDemoApp());
}

class StationMapDemoApp extends StatelessWidget {
  const StationMapDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Station Map Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6B50)),
      ),
      home: const GoogleMapsStationScreen(
        repository: MockStationMapRepository(),
      ),
    );
  }
}

class GoogleMapsStationScreen extends StatefulWidget {
  const GoogleMapsStationScreen({super.key, required this.repository});

  final StationMapRepository repository;

  @override
  State<GoogleMapsStationScreen> createState() =>
      _GoogleMapsStationScreenState();
}

class _GoogleMapsStationScreenState extends State<GoogleMapsStationScreen> {
  late final Future<List<StationMapStation>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = widget.repository.fetchStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<StationMapStation>>(
        future: _stationsFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<StationMapStation>> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _MapStateMessage(
                  title: 'Unable to load stations',
                  description:
                      'Mock station data could not be prepared for the map screen.',
                  icon: Icons.map_outlined,
                );
              }

              final List<StationMapStation> stations =
                  snapshot.data ?? <StationMapStation>[];
              if (stations.isEmpty) {
                return const _MapStateMessage(
                  title: 'No stations available',
                  description:
                      'There are no markers to show on the map right now.',
                  icon: Icons.location_off_outlined,
                );
              }

              return _StationMapView(
                stations: stations,
                onStationSelected: _openStationSheet,
              );
            },
      ),
    );
  }

  Future<void> _openStationSheet(StationMapStation station) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _StationDetailsBottomSheet(station: station);
      },
    );
  }
}

class _StationMapView extends StatelessWidget {
  const _StationMapView({
    required this.stations,
    required this.onStationSelected,
  });

  final List<StationMapStation> stations;
  final ValueChanged<StationMapStation> onStationSelected;

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = _centerOfStations(stations);
    final Set<Marker> markers = stations.map((StationMapStation station) {
      return Marker(
        markerId: MarkerId(station.id),
        position: station.position,
        infoWindow: InfoWindow.noText,
        icon: BitmapDescriptor.defaultMarkerWithHue(station.status.markerHue),
        onTap: () => onStationSelected(station),
      );
    }).toSet();

    final int alertCount = stations
        .where(
          (StationMapStation station) => station.status == StationStatus.alert,
        )
        .length;
    final int restockingCount = stations
        .where(
          (StationMapStation station) =>
              station.status == StationStatus.restocking,
        )
        .length;

    return Stack(
      children: <Widget>[
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 13.2,
          ),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: markers,
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Station Map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap any marker to open a scrollable station sheet.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _SummaryPill(
                              label: 'Stations',
                              value: '${stations.length}',
                              color: const Color(0xFF0E6B50),
                            ),
                            _SummaryPill(
                              label: 'Alert',
                              value: '$alertCount',
                              color: const Color(0xFFC62828),
                            ),
                            _SummaryPill(
                              label: 'Restocking',
                              value: '$restockingCount',
                              color: const Color(0xFFEF6C00),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LatLng _centerOfStations(List<StationMapStation> stations) {
    if (stations.isEmpty) {
      return const LatLng(37.5665, 126.9780);
    }

    double latitudeSum = 0;
    double longitudeSum = 0;
    for (final StationMapStation station in stations) {
      latitudeSum += station.position.latitude;
      longitudeSum += station.position.longitude;
    }

    return LatLng(
      latitudeSum / stations.length,
      longitudeSum / stations.length,
    );
  }
}

class _StationDetailsBottomSheet extends StatelessWidget {
  const _StationDetailsBottomSheet({required this.station});

  final StationMapStation station;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                station.displayId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                station.address,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  height: 1.4,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  _StatusBadge(status: station.status),
                                  _InlineSummaryChip(
                                    label: 'Station Code',
                                    value: station.stationCode,
                                  ),
                                  _InlineSummaryChip(
                                    label: 'Available',
                                    value:
                                        '${station.metrics.availableCycles}/${station.metrics.capacity}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                station.statusSummary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Table-like section',
                          child: _StationMetricsTable(station: station),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Chart section',
                          child: _StationChart(station: station),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Log / History list',
                          child: _StationLogsList(logs: station.logs),
                        ),
                      ],
                    ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _StationMetricsTable extends StatelessWidget {
  const _StationMetricsTable({required this.station});

  final StationMapStation station;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('Station code', station.stationCode),
      MapEntry<String, String>('Status', station.status.label),
      MapEntry<String, String>('Capacity', '${station.metrics.capacity} docks'),
      MapEntry<String, String>(
        'Available cycles',
        '${station.metrics.availableCycles}',
      ),
      MapEntry<String, String>(
        'Reserved now',
        '${station.metrics.reservedCycles}',
      ),
      MapEntry<String, String>(
        'Pending refill',
        '${station.metrics.pendingRefill}',
      ),
      MapEntry<String, String>(
        'Service level',
        '${station.metrics.serviceLevel}%',
      ),
      MapEntry<String, String>('Updated at', station.lastUpdatedLabel),
    ];

    return Table(
      border: TableBorder.all(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(14),
      ),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.4),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows
          .map((MapEntry<String, String> row) {
            return TableRow(
              children: <Widget>[
                _TableCellText(
                  text: row.key,
                  backgroundColor: const Color(0xFFF8FAFC),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                _TableCellText(
                  text: row.value,
                  backgroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

class _StationChart extends StatelessWidget {
  const _StationChart({required this.station});

  final StationMapStation station;

  @override
  Widget build(BuildContext context) {
    final int maxValue = station.chartData.fold<int>(1, (
      int currentMax,
      StationChartPoint point,
    ) {
      return point.value > currentMax ? point.value : currentMax;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Expected availability trend',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ...station.chartData.map((StationChartPoint point) {
          final double ratio = point.value / maxValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 56,
                  child: Text(
                    point.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 14,
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        station.status.chartColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${point.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StationLogsList extends StatelessWidget {
  const _StationLogsList({required this.logs});

  final List<StationLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Text(
        'No history is available for this station.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
      );
    }

    return Column(
      children: logs
          .map((StationLogEntry log) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.history,
                          color: Color(0xFF0E6B50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              log.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              log.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                height: 1.35,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log.timestampLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText({
    required this.text,
    required this.backgroundColor,
    required this.textStyle,
  });

  final String text;
  final Color backgroundColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      color: backgroundColor,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          '$label: $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _InlineSummaryChip extends StatelessWidget {
  const _InlineSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          '$label: $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final StationStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.badgeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MapStateMessage extends StatelessWidget {
  const _MapStateMessage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 42, color: const Color(0xFF0E6B50)),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4B5563)),
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

abstract class StationMapRepository {
  Future<List<StationMapStation>> fetchStations();
}

class MockStationMapRepository implements StationMapRepository {
  const MockStationMapRepository();

  @override
  Future<List<StationMapStation>> fetchStations() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    return const <StationMapStation>[
      StationMapStation(
        id: 'station-933',
        stationCode: 'ST-481',
        position: LatLng(37.5252, 126.9250),
        address: '서울특별시 영등포구 여의나루로 76, IFC몰 2번 게이트 앞 공공 자전거 거치 구역',
        status: StationStatus.healthy,
        statusSummary:
            'Current inventory is stable and the next hour forecast stays within the healthy range.',
        lastUpdatedLabel: 'Updated 5 minutes ago',
        metrics: StationSummaryMetrics(
          capacity: 18,
          availableCycles: 11,
          reservedCycles: 2,
          pendingRefill: 1,
          serviceLevel: 94,
        ),
        chartData: <StationChartPoint>[
          StationChartPoint(label: 'Now', value: 11),
          StationChartPoint(label: '09:00', value: 10),
          StationChartPoint(label: '10:00', value: 9),
          StationChartPoint(label: '11:00', value: 12),
          StationChartPoint(label: '12:00', value: 10),
          StationChartPoint(label: '13:00', value: 11),
        ],
        logs: <StationLogEntry>[
          StationLogEntry(
            title: 'Refill completed',
            message:
                'Worker Mina Kim restocked 3 cycles and verified dock power status without finding any hardware issue.',
            timestampLabel: 'Today, 08:32',
          ),
          StationLogEntry(
            title: 'Reservation spike',
            message:
                'Two commuter reservations were created in a short interval, but capacity stayed within the normal operating buffer.',
            timestampLabel: 'Today, 07:54',
          ),
        ],
      ),
      StationMapStation(
        id: 'station-4652',
        stationCode: 'ST-2425',
        position: LatLng(37.5131, 127.1025),
        address: '서울특별시 송파구 올림픽로 300, 롯데월드타워 월드파크 7번 출입구 맞은편 자전거 스테이션',
        status: StationStatus.alert,
        statusSummary:
            'Demand is outpacing returns, so this station needs a refill run before the next peak interval begins.',
        lastUpdatedLabel: 'Updated 2 minutes ago',
        metrics: StationSummaryMetrics(
          capacity: 22,
          availableCycles: 3,
          reservedCycles: 5,
          pendingRefill: 6,
          serviceLevel: 41,
        ),
        chartData: <StationChartPoint>[
          StationChartPoint(label: 'Now', value: 3),
          StationChartPoint(label: '09:00', value: 2),
          StationChartPoint(label: '10:00', value: 4),
          StationChartPoint(label: '11:00', value: 3),
          StationChartPoint(label: '12:00', value: 5),
          StationChartPoint(label: '13:00', value: 4),
        ],
        logs: <StationLogEntry>[
          StationLogEntry(
            title: 'Alert issued',
            message:
                'Low-cycle threshold was crossed after a sustained burst of reservations from nearby office towers.',
            timestampLabel: 'Today, 08:41',
          ),
          StationLogEntry(
            title: 'Dispatch requested',
            message:
                'A worker dispatch request was sent to the closest support crew with a suggested refill count of 6 cycles.',
            timestampLabel: 'Today, 08:43',
          ),
          StationLogEntry(
            title: 'Dock inspection note',
            message:
                'Dock 11 reports intermittent contact; users can still park, but monitoring remains active until the next manual check.',
            timestampLabel: 'Yesterday, 18:20',
          ),
        ],
      ),
      StationMapStation(
        id: 'station-956',
        stationCode: 'ST-1331',
        position: LatLng(37.5797, 126.9770),
        address: '서울특별시 종로구 세종대로 172, 광화문광장 북측 버스정류장 인근 자전거 대여소',
        status: StationStatus.healthy,
        statusSummary:
            'Availability is balanced and reservation pressure is currently low for the next forecast window.',
        lastUpdatedLabel: 'Updated 7 minutes ago',
        metrics: StationSummaryMetrics(
          capacity: 20,
          availableCycles: 13,
          reservedCycles: 1,
          pendingRefill: 0,
          serviceLevel: 96,
        ),
        chartData: <StationChartPoint>[
          StationChartPoint(label: 'Now', value: 13),
          StationChartPoint(label: '09:00', value: 12),
          StationChartPoint(label: '10:00', value: 14),
          StationChartPoint(label: '11:00', value: 13),
          StationChartPoint(label: '12:00', value: 12),
          StationChartPoint(label: '13:00', value: 13),
        ],
        logs: <StationLogEntry>[
          StationLogEntry(
            title: 'Routine check',
            message:
                'Morning diagnostics completed successfully and there were no parking lock anomalies detected.',
            timestampLabel: 'Today, 07:10',
          ),
        ],
      ),
      StationMapStation(
        id: 'station-906',
        stationCode: 'ST-454',
        position: LatLng(37.4981, 127.0276),
        address: '서울특별시 강남구 강남대로 390, 강남역 11번 출구와 테헤란로 횡단보도 사이 보행로 옆',
        status: StationStatus.restocking,
        statusSummary:
            'A refill vehicle is already heading here, so availability should recover within the next operating cycle.',
        lastUpdatedLabel: 'Updated 1 minute ago',
        metrics: StationSummaryMetrics(
          capacity: 16,
          availableCycles: 5,
          reservedCycles: 3,
          pendingRefill: 4,
          serviceLevel: 68,
        ),
        chartData: <StationChartPoint>[
          StationChartPoint(label: 'Now', value: 5),
          StationChartPoint(label: '09:00', value: 4),
          StationChartPoint(label: '10:00', value: 6),
          StationChartPoint(label: '11:00', value: 8),
          StationChartPoint(label: '12:00', value: 9),
          StationChartPoint(label: '13:00', value: 8),
        ],
        logs: <StationLogEntry>[
          StationLogEntry(
            title: 'Van dispatched',
            message:
                'Restocking van departed from the southern hub and is expected to arrive in approximately 18 minutes.',
            timestampLabel: 'Today, 08:48',
          ),
          StationLogEntry(
            title: 'Queue watch',
            message:
                'Reservation queue remains manageable, but the platform is keeping a close watch on lunch-hour demand.',
            timestampLabel: 'Today, 08:50',
          ),
        ],
      ),
      StationMapStation(
        id: 'station-905',
        stationCode: 'ST-453',
        position: LatLng(37.5563, 126.9236),
        address: '서울특별시 마포구 양화로 188, 홍대입구역 8번 출구 앞 광장 연결 보행통로 인근',
        status: StationStatus.healthy,
        statusSummary:
            'The station is serving a high-traffic area well, with enough spare docks and a healthy return forecast.',
        lastUpdatedLabel: 'Updated 4 minutes ago',
        metrics: StationSummaryMetrics(
          capacity: 24,
          availableCycles: 15,
          reservedCycles: 4,
          pendingRefill: 0,
          serviceLevel: 91,
        ),
        chartData: <StationChartPoint>[
          StationChartPoint(label: 'Now', value: 15),
          StationChartPoint(label: '09:00', value: 14),
          StationChartPoint(label: '10:00', value: 13),
          StationChartPoint(label: '11:00', value: 15),
          StationChartPoint(label: '12:00', value: 16),
          StationChartPoint(label: '13:00', value: 15),
        ],
        logs: <StationLogEntry>[
          StationLogEntry(
            title: 'Crowd advisory',
            message:
                'Foot traffic increased because of an event nearby, but extra parking capacity kept turnaround times stable.',
            timestampLabel: 'Today, 08:05',
          ),
          StationLogEntry(
            title: 'Night shift summary',
            message:
                'Overnight operations closed without unresolved faults and the bike count reconciled with depot records.',
            timestampLabel: 'Today, 06:12',
          ),
        ],
      ),
    ];
  }
}

class StationMapStation {
  const StationMapStation({
    required this.id,
    required this.stationCode,
    required this.position,
    required this.address,
    required this.status,
    required this.statusSummary,
    required this.lastUpdatedLabel,
    required this.metrics,
    required this.chartData,
    required this.logs,
  });

  final String id;
  final String stationCode;
  final LatLng position;
  final String address;
  final StationStatus status;
  final String statusSummary;
  final String lastUpdatedLabel;
  final StationSummaryMetrics metrics;
  final List<StationChartPoint> chartData;
  final List<StationLogEntry> logs;

  String get displayId => id;
}

class StationSummaryMetrics {
  const StationSummaryMetrics({
    required this.capacity,
    required this.availableCycles,
    required this.reservedCycles,
    required this.pendingRefill,
    required this.serviceLevel,
  });

  final int capacity;
  final int availableCycles;
  final int reservedCycles;
  final int pendingRefill;
  final int serviceLevel;
}

class StationChartPoint {
  const StationChartPoint({required this.label, required this.value});

  final String label;
  final int value;
}

class StationLogEntry {
  const StationLogEntry({
    required this.title,
    required this.message,
    required this.timestampLabel,
  });

  final String title;
  final String message;
  final String timestampLabel;
}

enum StationStatus {
  healthy,
  restocking,
  alert;

  String get label {
    switch (this) {
      case StationStatus.healthy:
        return 'Healthy';
      case StationStatus.restocking:
        return 'Restocking';
      case StationStatus.alert:
        return 'Alert';
    }
  }

  Color get badgeColor {
    switch (this) {
      case StationStatus.healthy:
        return const Color(0xFF0F766E);
      case StationStatus.restocking:
        return const Color(0xFFEA580C);
      case StationStatus.alert:
        return const Color(0xFFDC2626);
    }
  }

  Color get chartColor {
    switch (this) {
      case StationStatus.healthy:
        return const Color(0xFF0E9F6E);
      case StationStatus.restocking:
        return const Color(0xFFF59E0B);
      case StationStatus.alert:
        return const Color(0xFFEF4444);
    }
  }

  double get markerHue {
    switch (this) {
      case StationStatus.healthy:
        return BitmapDescriptor.hueGreen;
      case StationStatus.restocking:
        return BitmapDescriptor.hueOrange;
      case StationStatus.alert:
        return BitmapDescriptor.hueRed;
    }
  }
}
