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
  StationMapStation? _selectedStation;
  bool _isDetailsDrawerOpen = false;

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

              final StationMapStation selectedStation = _selectedStationFor(
                stations,
              );

              return _StationMapView(
                stations: stations,
                selectedStation: selectedStation,
                isDetailsDrawerOpen: _isDetailsDrawerOpen,
                onStationSelected: _showStationDetails,
                onCloseDrawer: _closeDetailsDrawer,
              );
            },
      ),
    );
  }

  StationMapStation _selectedStationFor(List<StationMapStation> stations) {
    final StationMapStation? selectedStation = _selectedStation;
    if (selectedStation == null) {
      return stations.first;
    }

    for (final StationMapStation station in stations) {
      if (station.id == selectedStation.id) {
        return station;
      }
    }

    return stations.first;
  }

  void _showStationDetails(StationMapStation station) {
    setState(() {
      _selectedStation = station;
      _isDetailsDrawerOpen = true;
    });
  }

  void _closeDetailsDrawer() {
    if (!_isDetailsDrawerOpen) {
      return;
    }

    setState(() {
      _isDetailsDrawerOpen = false;
    });
  }
}

class _StationMapView extends StatelessWidget {
  const _StationMapView({
    required this.stations,
    required this.selectedStation,
    required this.isDetailsDrawerOpen,
    required this.onStationSelected,
    required this.onCloseDrawer,
  });

  final List<StationMapStation> stations;
  final StationMapStation selectedStation;
  final bool isDetailsDrawerOpen;
  final ValueChanged<StationMapStation> onStationSelected;
  final VoidCallback onCloseDrawer;

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = _centerOfStations(stations);
    final Set<Marker> markers = stations.map((StationMapStation station) {
      return Marker(
        markerId: MarkerId(station.id),
        position: station.position,
        infoWindow: InfoWindow.noText,
        icon: BitmapDescriptor.defaultMarkerWithHue(station.markerHue),
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showPinnedPanel = constraints.maxWidth >= 1120;
        final double rawPanelWidth = showPinnedPanel
            ? 388
            : constraints.maxWidth * 0.88;
        final double panelWidth = rawPanelWidth.clamp(300.0, 388.0).toDouble();
        final bool showOverlayDrawer = !showPinnedPanel && isDetailsDrawerOpen;

        return Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                if (showPinnedPanel)
                  SizedBox(
                    width: panelWidth,
                    child: _StationDetailsDrawerPanel(
                      station: selectedStation,
                      showCloseButton: false,
                      onClose: onCloseDrawer,
                    ),
                  ),
                Expanded(
                  child: Stack(
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
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                      Text(
                                        showPinnedPanel
                                            ? 'Select a marker to refresh the left details panel.'
                                            : 'Tap a marker to open the left drawer and review station details.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF4B5563),
                                        ),
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
                                          _SummaryPill(
                                            label: 'Selected',
                                            value: selectedStation.stationCode,
                                            color: selectedStation.markerColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _StationColorLegend(
                                        stations: stations,
                                        selectedStationId: selectedStation.id,
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
                  ),
                ),
              ],
            ),
            if (!showPinnedPanel)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !showOverlayDrawer,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: showOverlayDrawer ? 1 : 0,
                    child: GestureDetector(
                      onTap: onCloseDrawer,
                      child: Container(color: const Color(0x66000000)),
                    ),
                  ),
                ),
              ),
            if (!showPinnedPanel)
              SafeArea(
                child: AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  top: 12,
                  bottom: 12,
                  left: showOverlayDrawer ? 0 : -(panelWidth + 24),
                  child: SizedBox(
                    width: panelWidth,
                    child: _StationDetailsDrawerPanel(
                      station: selectedStation,
                      showCloseButton: true,
                      onClose: onCloseDrawer,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

class _StationDetailsDrawerPanel extends StatelessWidget {
  const _StationDetailsDrawerPanel({
    required this.station,
    required this.showCloseButton,
    required this.onClose,
  });

  final StationMapStation station;
  final bool showCloseButton;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      elevation: showCloseButton ? 16 : 0,
      borderRadius: showCloseButton
          ? const BorderRadius.horizontal(right: Radius.circular(28))
          : BorderRadius.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 10, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Station Details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close details',
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: station.markerColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 6),
                                  Text(
                                    station.lastUpdatedLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          station.address,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            height: 1.45,
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
                          maxLines: 4,
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
                    title: 'Quick Metrics',
                    child: _StationMetricsTable(station: station),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Forecast',
                    child: _StationChart(station: station),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Recent Activity',
                    child: _StationLogsList(
                      logs: station.logs.take(3).toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final List<_MetricCardData> metrics = <_MetricCardData>[
      _MetricCardData(
        label: 'Available',
        value: '${station.metrics.availableCycles}',
        helper: 'cycles ready',
        accentColor: station.markerColor,
      ),
      _MetricCardData(
        label: 'Capacity',
        value: '${station.metrics.capacity}',
        helper: 'total docks',
        accentColor: const Color(0xFF0F766E),
      ),
      _MetricCardData(
        label: 'Reserved',
        value: '${station.metrics.reservedCycles}',
        helper: 'current demand',
        accentColor: const Color(0xFF2563EB),
      ),
      _MetricCardData(
        label: 'Pending Refill',
        value: '${station.metrics.pendingRefill}',
        helper: 'cycles needed',
        accentColor: const Color(0xFFEA580C),
      ),
      _MetricCardData(
        label: 'Service Level',
        value: '${station.metrics.serviceLevel}%',
        helper: 'current health',
        accentColor: station.status.badgeColor,
      ),
      _MetricCardData(
        label: 'Status',
        value: station.status.label,
        helper: station.lastUpdatedLabel,
        accentColor: const Color(0xFF475569),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double spacing = 12;
        final double availableWidth = constraints.maxWidth;
        final bool singleColumn = availableWidth < 320;
        final double tileWidth = singleColumn
            ? availableWidth
            : (availableWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (_MetricCardData metric) => SizedBox(
                  width: tileWidth,
                  child: _MetricCard(metric: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _StationChart extends StatelessWidget {
  const _StationChart({required this.station});

  final StationMapStation station;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double spacing = 12;
        final double availableWidth = constraints.maxWidth;
        final bool singleColumn = availableWidth < 300;
        final double tileWidth = singleColumn
            ? availableWidth
            : (availableWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: station.chartData
              .map(
                (StationChartPoint point) => SizedBox(
                  width: tileWidth,
                  child: _ForecastCard(
                    label: point.label,
                    value: '${point.value} cycles',
                    color: station.status.chartColor,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
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

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.helper,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String helper;
  final Color accentColor;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricCardData metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: metric.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: metric.accentColor.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: metric.accentColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metric.helper,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationColorLegend extends StatelessWidget {
  const _StationColorLegend({
    required this.stations,
    required this.selectedStationId,
  });

  final List<StationMapStation> stations;
  final String selectedStationId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stations
          .map(
            (StationMapStation station) => _LegendChip(
              label: station.stationCode,
              color: station.markerColor,
              isSelected: station.id == selectedStationId,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.isSelected,
  });

  final String label;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.18) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected ? color : const Color(0xFFD7DEE8),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
        markerHue: BitmapDescriptor.hueGreen,
        markerColor: Color(0xFF16A34A),
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
        markerHue: BitmapDescriptor.hueAzure,
        markerColor: Color(0xFF0284C7),
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
        markerHue: BitmapDescriptor.hueBlue,
        markerColor: Color(0xFF2563EB),
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
        markerHue: BitmapDescriptor.hueOrange,
        markerColor: Color(0xFFEA580C),
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
        markerHue: BitmapDescriptor.hueRose,
        markerColor: Color(0xFFDB2777),
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
    required this.markerHue,
    required this.markerColor,
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
  final double markerHue;
  final Color markerColor;
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
