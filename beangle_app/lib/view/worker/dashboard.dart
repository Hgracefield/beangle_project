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
// - 04-Apr-2026, Codex
//   - Moved station details into a left drawer-style panel.
//   - Replaced fixed-width detail tables with responsive summary cards.
// ===============================================
import 'dart:convert';
import 'dart:async';

import 'package:beangle_app/model/chat_service.dart';
import 'package:beangle_app/model/work_api.dart';
import 'package:beangle_app/model/work_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beangle_app/view/auth/auth_page.dart';
import 'package:beangle_app/view/worker/worker_chat_list.dart';
import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  static const Color _tableBorderColor = Color(0xFF91B184);
  static const Color _stationColumnColor = Color(0xFFE8F2E1);

  static const List<_StationSeed> _stationSeeds = <_StationSeed>[
    _StationSeed(
      stationCode: 'ST-481',
      stationNumber: 933,
      fallbackName: '상현',
      latitude: 37.612484,
      longitude: 126.914879,
      markerHue: BitmapDescriptor.hueGreen,
      markerColor: Color(0xFF16A34A),
      fallbackAvailable: 9,
      fallbackParking: 6,
    ),
    _StationSeed(
      stationCode: 'ST-2425',
      stationNumber: 4652,
      fallbackName: '다원',
      latitude: 37.600000,
      longitude: 126.920000,
      markerHue: BitmapDescriptor.hueAzure,
      markerColor: Color(0xFF0284C7),
      fallbackAvailable: 0,
      fallbackParking: 0,
    ),
    _StationSeed(
      stationCode: 'ST-1331',
      stationNumber: 956,
      fallbackName: '찬솔',
      latitude: 37.594414,
      longitude: 126.918015,
      markerHue: BitmapDescriptor.hueBlue,
      markerColor: Color(0xFF2563EB),
      fallbackAvailable: 10,
      fallbackParking: 8,
    ),
    _StationSeed(
      stationCode: 'ST-454',
      stationNumber: 906,
      fallbackName: '신영',
      latitude: 37.61721,
      longitude: 126.919579,
      markerHue: BitmapDescriptor.hueViolet,
      markerColor: Color(0xFF7C3AED),
      fallbackAvailable: 5,
      fallbackParking: 4,
    ),
    _StationSeed(
      stationCode: 'ST-453',
      stationNumber: 905,
      fallbackName: '혜전',
      latitude: 37.636234,
      longitude: 126.918999,
      markerHue: BitmapDescriptor.hueRose,
      markerColor: Color(0xFFDB2777),
      fallbackAvailable: 11,
      fallbackParking: 9,
    ),
  ];

  final GetStorage _storage = GetStorage();
  final WorkApi _workApi = WorkApi();

  VoidCallback? _cancelReservationStorageListener;
  StreamSubscription? _chatRoomsSubscription;
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
  bool _hasSeenInitialAdminRoomSnapshot = false;
  int _lastAdminUnreadCount = 0;
  String? _lastAdminNotifiedMessage;
  bool _isDetailsDrawerOpen = false;

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

    _startAdminChatNotifications();
    _initializeReservationCycleTable();
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
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

  void _openChatRooms() {
    Get.to(
      () => Scaffold(
        appBar: AppBar(
          title: const Text(
            '채팅 리스트',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: const SafeArea(child: WorkerChatListPage()),
      ),
    );
  }

  int _unreadCountForRole(Map<String, dynamic>? data, String role) {
    if (data == null) {
      return 0;
    }

    final dynamic unreadCounts = data['unreadCounts'];
    if (unreadCounts is Map) {
      final dynamic roleCount = unreadCounts[role];
      return int.tryParse(roleCount?.toString() ?? '') ?? 0;
    }

    final String legacyKey =
        '${role[0].toUpperCase()}${role.substring(1)}UnreadCount';
    return int.tryParse(data[legacyKey]?.toString() ?? '') ?? 0;
  }

  void _startAdminChatNotifications() {
    if (!FirebaseBootstrap.isReady) {
      return;
    }

    _chatRoomsSubscription = ChatService.watchRooms().listen((snapshot) {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          snapshot.docs;
      final int unreadCount = docs.fold<int>(
        0,
        (int sum, QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            sum + _unreadCountForRole(doc.data(), 'admin'),
      );

      if (_hasSeenInitialAdminRoomSnapshot &&
          unreadCount > _lastAdminUnreadCount &&
          mounted) {
        Map<String, dynamic>? incomingData;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
          final Map<String, dynamic> data = doc.data();
          if (_unreadCountForRole(data, 'admin') > 0 &&
              data['lastSenderRole']?.toString() == 'user') {
            incomingData = data;
            break;
          }
        }

        final String message = incomingData?['lastMessage']?.toString() ?? '';
        final String userName =
            incomingData?['userName']?.toString().trim().isNotEmpty == true
            ? incomingData!['userName'].toString()
            : '사용자';

        if (message.isNotEmpty && message != _lastAdminNotifiedMessage) {
          _lastAdminNotifiedMessage = message;
          _showIncomingChatBanner(
            title: '$userName 님의 새 메시지',
            message: message,
            onOpen: _openChatRooms,
          );
        }
      }

      _hasSeenInitialAdminRoomSnapshot = true;
      _lastAdminUnreadCount = unreadCount;
    });
  }

  void _showIncomingChatBanner({
    required String title,
    required String message,
    required VoidCallback onOpen,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          leading: const Icon(Icons.chat_bubble_outline),
          backgroundColor: const Color(0xFFF4F8EF),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                messenger.clearMaterialBanners();
                onOpen();
              },
              child: const Text('열기'),
            ),
            TextButton(
              onPressed: messenger.clearMaterialBanners,
              child: const Text('닫기'),
            ),
          ],
        ),
      );

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        messenger.clearMaterialBanners();
      }
    });
  }

  Widget _buildChatActionButton() {
    if (!FirebaseBootstrap.isReady) {
      return IconButton(
        onPressed: _openChatRooms,
        tooltip: '채팅',
        icon: const Icon(Icons.chat_bubble_outline),
      );
    }

    return StreamBuilder(
      stream: ChatService.watchRooms(),
      builder: (context, snapshot) {
        final int unreadCount = snapshot.hasData
            ? snapshot.data!.docs.fold<int>(
                0,
                (int sum, QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    sum + _unreadCountForRole(doc.data(), 'admin'),
              )
            : 0;

        return IconButton(
          onPressed: _openChatRooms,
          tooltip: '채팅',
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
        );
      },
    );
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

    try {
      final List<WorkRecord> works = await _workApi.fetchWorks();
      if (requestToken != _refillLogRequestToken || !mounted) {
        return;
      }

      final Map<int, _WorkerDirectoryItem> workerDirectory =
          await _loadWorkerDirectory();
      if (requestToken != _refillLogRequestToken || !mounted) {
        return;
      }

      final int? stationCodeId = selectedStationSeed.codeId;
      final Set<int> stationIds = <int>{
        ?stationCodeId,
        selectedStationSeed.stationNumber,
      };
      final List<_RefillLogItem> refillLogs =
          works
              .where(
                (WorkRecord item) =>
                    stationIds.contains(item.stationId) && item.count > 0,
              )
              .map((WorkRecord item) {
                final _WorkerDirectoryItem? worker =
                    workerDirectory[item.workerId];
                return _RefillLogItem(
                  refillTime: item.worktime,
                  refillCount: item.count,
                  workerId: item.workerId,
                  workerName: worker?.name,
                );
              })
              .where(
                (_RefillLogItem item) =>
                    item.refillTime != DateTime.fromMillisecondsSinceEpoch(0),
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
        _refillLogErrorText = 'Refill logs could not be loaded.';
      });
    }
  }

  Future<Map<int, _WorkerDirectoryItem>> _loadWorkerDirectory() async {
    try {
      final Uri workerUri = Uri.parse('$_pythonApiBaseUrl/worker/select');
      final http.Response response = await http.get(workerUri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <int, _WorkerDirectoryItem>{};
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawWorkers =
          json['results'] as List<dynamic>? ?? <dynamic>[];
      final Map<int, _WorkerDirectoryItem> workerDirectory =
          <int, _WorkerDirectoryItem>{};

      for (final dynamic item in rawWorkers) {
        final _WorkerDirectoryItem worker = _WorkerDirectoryItem.fromJson(
          item as Map<String, dynamic>,
        );
        workerDirectory[worker.workerId] = worker;
      }

      return workerDirectory;
    } catch (_) {
      return const <int, _WorkerDirectoryItem>{};
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
      final double latitude =
          double.tryParse(row['stationLatitude']?.toString() ?? '') ??
          seed.latitude;
      final double longitude =
          double.tryParse(row['stationLongitude']?.toString() ?? '') ??
          seed.longitude;
      final String stationName = row['stationName']?.toString() ?? '';

      return _StationAvailabilitySnapshot(
        name: stationName.trim().isEmpty ? seed.fallbackName : stationName,
        available: available,
        parking: (rackCount - available).clamp(0, rackCount),
        latitude: latitude,
        longitude: longitude,
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

  _ReservationCycleRow? _reservationCycleRowForCode(String stationCode) {
    for (final _ReservationCycleRow row in _reservationCycleRows) {
      if (row.stationCode == stationCode) {
        return row;
      }
    }
    return null;
  }

  _StationSeed? _stationSeedForCode(String stationCode) {
    for (final _StationSeed seed in _stationSeeds) {
      if (seed.stationCode == stationCode) {
        return seed;
      }
    }
    return null;
  }

  LatLng get _initialMapTarget {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (final _StationSeed seed in _stationSeeds) {
      final _StationAvailabilitySnapshot snapshot =
          _stationAvailabilityByCode[seed.stationCode] ?? seed.toSnapshot();
      latitudeSum += snapshot.latitude;
      longitudeSum += snapshot.longitude;
    }

    return LatLng(
      latitudeSum / _stationSeeds.length,
      longitudeSum / _stationSeeds.length,
    );
  }

  String _stationName(_StationSeed seed) {
    return (_stationAvailabilityByCode[seed.stationCode] ?? seed.toSnapshot())
        .name;
  }

  double _stationMarkerHue(_StationSeed seed) {
    return seed.markerHue;
  }

  Color _stationMarkerColor(_StationSeed seed) {
    return seed.markerColor;
  }

  Set<Marker> _buildStationMarkers() {
    return _stationSeeds.map((_StationSeed seed) {
      final _StationAvailabilitySnapshot snapshot =
          _stationAvailabilityByCode[seed.stationCode] ?? seed.toSnapshot();

      return Marker(
        markerId: MarkerId(seed.stationCode),
        position: snapshot.position,
        infoWindow: InfoWindow.noText,
        icon: BitmapDescriptor.defaultMarkerWithHue(_stationMarkerHue(seed)),
        onTap: () => _openStationDetailsDrawer(seed.stationCode),
      );
    }).toSet();
  }

  Future<void> _openStationDetailsDrawer(String stationCode) async {
    if (_selectedStationCode != stationCode || !_isDetailsDrawerOpen) {
      setState(() {
        _selectedStationCode = stationCode;
        _isDetailsDrawerOpen = true;
      });
    }

    await _loadRefillLogsForSelectedStation();
  }

  void _closeStationDetailsDrawer() {
    if (!_isDetailsDrawerOpen) {
      return;
    }

    setState(() {
      _isDetailsDrawerOpen = false;
    });
  }

  bool _needsAttention(_ReservationCycleRow row) {
    return row.currentAvailableCycleCount <= 3 ||
        row.availableCycleCountAfter4Hours < row.currentAvailableCycleCount;
  }

  Widget _buildStationDetailsDrawer({required bool showCloseButton}) {
    final String? stationCode =
        _selectedStationCode ??
        (_reservationCycleRows.isNotEmpty
            ? _reservationCycleRows.first.stationCode
            : null);
    final _ReservationCycleRow? row = stationCode == null
        ? null
        : _reservationCycleRowForCode(stationCode);
    final _StationSeed? seed = stationCode == null
        ? null
        : _stationSeedForCode(stationCode);

    if (row == null || seed == null) {
      return Material(
        color: _pageBackgroundColor,
        elevation: showCloseButton ? 16 : 0,
        borderRadius: showCloseButton
            ? const BorderRadius.horizontal(right: Radius.circular(28))
            : BorderRadius.zero,
        clipBehavior: Clip.antiAlias,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '마커를 선택하면 스테이션 상세 정보가 왼쪽 패널에 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }
    final _StationAvailabilitySnapshot snapshot =
        _stationAvailabilityByCode[seed.stationCode] ?? seed.toSnapshot();
    final int rackCount = snapshot.available + snapshot.parking;
    final int forecastDelta =
        row.availableCycleCountAfter8Hours - row.currentAvailableCycleCount;
    final bool needsAttention = _needsAttention(row);

    return Material(
      color: _pageBackgroundColor,
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
                      color: Color(0xFF1F3516),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    onPressed: _closeStationDetailsDrawer,
                    tooltip: '닫기',
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
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: _stationMarkerColor(seed),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      seed.displayId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F3516),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _stationName(seed),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        height: 1.4,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _buildSummaryChip(
                                color: const Color(0xFFF1F5F9),
                                textColor: const Color(0xFF334155),
                                text: row.stationCode,
                              ),
                              _buildSummaryChip(
                                color: _stationMarkerColor(
                                  seed,
                                ).withValues(alpha: 0.12),
                                textColor: _stationMarkerColor(seed),
                                text: '현재 ${row.currentAvailableCycleCount}대',
                              ),
                              _buildSummaryChip(
                                color: needsAttention
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFDCFCE7),
                                textColor: needsAttention
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF166534),
                                text: needsAttention ? '주의 필요' : '안정',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Quick Summary'),
                  const SizedBox(height: 10),
                  _buildSectionFrame(
                    child: _buildStationSummaryGrid(
                      row: row,
                      seed: seed,
                      rackCount: rackCount,
                      forecastDelta: forecastDelta,
                      needsAttention: needsAttention,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Forecast Window'),
                  const SizedBox(height: 10),
                  _buildSectionFrame(child: _buildForecastCards(row)),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Refill Logs'),
                  const SizedBox(height: 10),
                  _buildSectionFrame(child: _buildRefillLogSection()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required Color color,
    required Color textColor,
    required String text,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
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

  Widget _buildStationSummaryGrid({
    required _ReservationCycleRow row,
    required _StationSeed seed,
    required int rackCount,
    required int forecastDelta,
    required bool needsAttention,
  }) {
    final List<_DashboardMetricCardData> cards = <_DashboardMetricCardData>[
      _DashboardMetricCardData(
        label: '현재 자전거',
        value: '${row.currentAvailableCycleCount}대',
        helper: '실시간 가용 수량',
        accentColor: _stationMarkerColor(seed),
      ),
      _DashboardMetricCardData(
        label: '빈 거치대',
        value:
            '${(rackCount - row.currentAvailableCycleCount).clamp(0, rackCount)}곳',
        helper: '전체 거치대 $rackCount곳',
        accentColor: const Color(0xFF2563EB),
      ),
      _DashboardMetricCardData(
        label: '+4시간 예측',
        value: '${row.availableCycleCountAfter4Hours}대',
        helper: '중간 체크 시점',
        accentColor: _primaryColor,
      ),
      _DashboardMetricCardData(
        label: '+8시간 변화',
        value: '${forecastDelta >= 0 ? '+' : ''}$forecastDelta대',
        helper: '현재 대비 증감',
        accentColor: forecastDelta >= 0
            ? const Color(0xFF166534)
            : const Color(0xFFB91C1C),
      ),
      _DashboardMetricCardData(
        label: '상태',
        value: needsAttention ? '주의 필요' : '안정',
        helper: needsAttention ? '보충 우선 확인 권장' : '현재 흐름 안정적',
        accentColor: needsAttention
            ? const Color(0xFF92400E)
            : const Color(0xFF166534),
      ),
      _DashboardMetricCardData(
        label: '스테이션 번호',
        value: '${seed.stationNumber}',
        helper: '코드 ${seed.stationCode}',
        accentColor: const Color(0xFF475569),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double spacing = 12;
        final double availableWidth = constraints.maxWidth - 24;
        final bool singleColumn = availableWidth < 320;
        final double tileWidth = singleColumn
            ? availableWidth
            : (availableWidth - spacing) / 2;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map(
                  (_DashboardMetricCardData card) => SizedBox(
                    width: tileWidth,
                    child: _DashboardMetricCard(card: card),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildForecastCards(_ReservationCycleRow row) {
    final List<_ForecastSnapshot> forecasts = _ReservationCycleColumn.values
        .map(
          (_ReservationCycleColumn column) => _ForecastSnapshot(
            label: column.chartLabel,
            value: '${row.valueFor(column)}대',
          ),
        )
        .toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final double availableWidth = constraints.maxWidth - 24;
        final int columns = availableWidth >= 480
            ? 3
            : availableWidth >= 300
            ? 2
            : 1;
        final double tileWidth =
            (availableWidth - (spacing * (columns - 1))) / columns;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: forecasts
                .map(
                  (_ForecastSnapshot forecast) => SizedBox(
                    width: tileWidth,
                    child: _DashboardForecastCard(
                      forecast: forecast,
                      accentColor: _primaryColor,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildMapSummaryCard() {
    final String? selectedStationCode =
        _selectedStationCode ??
        (_reservationCycleRows.isNotEmpty
            ? _reservationCycleRows.first.stationCode
            : null);
    final int attentionCount = _reservationCycleRows
        .where(_needsAttention)
        .length;
    final _StationSeed? selectedSeed = selectedStationCode == null
        ? null
        : _stationSeedForCode(selectedStationCode);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Worker Dashboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F3516),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '마커를 누르면 지도 위가 아니라 왼쪽 패널에서 상세 정보를 확인할 수 있습니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildSummaryChip(
                  color: const Color(0xFFE8F2E1),
                  textColor: _primaryColor,
                  text: '스테이션 ${_stationSeeds.length}곳',
                ),
                _buildSummaryChip(
                  color: const Color(0xFFF1F5F9),
                  textColor: const Color(0xFF334155),
                  text: '주의 $attentionCount곳',
                ),
                if (selectedSeed != null)
                  _buildSummaryChip(
                    color: selectedSeed.markerColor.withValues(alpha: 0.14),
                    textColor: selectedSeed.markerColor,
                    text: '선택 ${selectedSeed.stationCode}',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildMarkerLegend(selectedStationCode),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerLegend(String? selectedStationCode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _stationSeeds
          .map(
            (_StationSeed seed) => _MarkerLegendChip(
              label: seed.stationCode,
              color: seed.markerColor,
              isSelected: seed.stationCode == selectedStationCode,
            ),
          )
          .toList(growable: false),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
          _buildChatActionButton(),
          IconButton(
            onPressed: _logout,
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ColoredBox(
        color: _pageBackgroundColor,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showPinnedPanel = constraints.maxWidth >= 1120;
            final double rawPanelWidth = showPinnedPanel
                ? 400
                : constraints.maxWidth * 0.88;
            final double panelWidth = rawPanelWidth
                .clamp(300.0, 400.0)
                .toDouble();
            final bool showOverlayDrawer =
                !showPinnedPanel && _isDetailsDrawerOpen;

            return Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (showPinnedPanel)
                      SizedBox(
                        width: panelWidth,
                        child: _buildStationDetailsDrawer(
                          showCloseButton: false,
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _initialMapTarget,
                              zoom: 13.2,
                            ),
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            markers: _buildStationMarkers(),
                          ),
                          SafeArea(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 760,
                                  ),
                                  child: _buildMapSummaryCard(),
                                ),
                              ),
                            ),
                          ),
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                              ),
                            ),
                          if (!_isLoading && _reservationCycleRows.isEmpty)
                            const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No station data available.'),
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
                          onTap: _closeStationDetailsDrawer,
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
                        child: _buildStationDetailsDrawer(
                          showCloseButton: true,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
    required this.fallbackName,
    required this.latitude,
    required this.longitude,
    required this.markerHue,
    required this.markerColor,
    required this.fallbackAvailable,
    required this.fallbackParking,
  });

  final String stationCode;
  final int stationNumber;
  final String fallbackName;
  final double latitude;
  final double longitude;
  final double markerHue;
  final Color markerColor;
  final int fallbackAvailable;
  final int fallbackParking;

  int? get codeId => int.tryParse(stationCode.replaceFirst('ST-', ''));

  String get displayId =>
      'station-${codeId?.toString() ?? stationCode.replaceFirst('ST-', '')}';

  _StationAvailabilitySnapshot toSnapshot() {
    return _StationAvailabilitySnapshot(
      name: fallbackName,
      available: fallbackAvailable,
      parking: fallbackParking,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _StationAvailabilitySnapshot {
  const _StationAvailabilitySnapshot({
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

  LatLng get position => LatLng(latitude, longitude);
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

class _DashboardMetricCardData {
  const _DashboardMetricCardData({
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

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({required this.card});

  final _DashboardMetricCardData card;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: card.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: card.accentColor.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              card.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: card.accentColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.helper,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastSnapshot {
  const _ForecastSnapshot({required this.label, required this.value});

  final String label;
  final String value;
}

class _DashboardForecastCard extends StatelessWidget {
  const _DashboardForecastCard({
    required this.forecast,
    required this.accentColor,
  });

  final _ForecastSnapshot forecast;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6D6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    forecast.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    forecast.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
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

class _MarkerLegendChip extends StatelessWidget {
  const _MarkerLegendChip({
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
        color: isSelected ? color.withValues(alpha: 0.16) : Colors.white,
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

class _WorkerDirectoryItem {
  const _WorkerDirectoryItem({required this.workerId, required this.name});

  final int workerId;
  final String? name;

  factory _WorkerDirectoryItem.fromJson(Map<String, dynamic> json) {
    return _WorkerDirectoryItem(
      workerId: int.tryParse(json['worker_id']?.toString() ?? '') ?? 0,
      name: json['worker_name']?.toString(),
    );
  }
}

class _RefillLogItem {
  const _RefillLogItem({
    required this.refillTime,
    this.refillCount,
    this.workerId,
    this.workerName,
  });

  final DateTime refillTime;
  final int? refillCount;
  final int? workerId;
  final String? workerName;
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
