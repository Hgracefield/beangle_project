import 'dart:async';

import 'package:beangle_app/app_shell.dart';
import 'package:beangle_app/reservation/model/reservation_api.dart';
import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ReservationPage extends StatelessWidget {
  const ReservationPage({
    super.key,
    this.initialReservation,
    this.initialStationName,
  });

  final ReservationInfo? initialReservation;
  final String? initialStationName;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '예약',
      currentRoute: AppRoutes.reservation,
      body: _ReservationView(
        initialReservation: initialReservation,
        initialStationName: initialStationName,
      ),
    );
  }
}

class _ReservationView extends StatefulWidget {
  const _ReservationView({this.initialReservation, this.initialStationName});

  final ReservationInfo? initialReservation;
  final String? initialStationName;

  @override
  State<_ReservationView> createState() => _ReservationViewState();
}

class _ReservationViewState extends State<_ReservationView> {
  final ReservationApi _api = ReservationApi();
  final GetStorage _storage = GetStorage();

  List<ReservationInfo> _reservations = <ReservationInfo>[];
  ReservationInfo? _pendingReservation;
  String? _pendingStationName;
  int? _userId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Timer? _reservationRefreshTimer;

  Color get _pageBackgroundColor => const Color(0xFFF5F8F1);
  Color get _panelColor => const Color(0xFFF7FBF4);
  Color get _accentColor => const Color(0xFF49992E);
  Color get _accentSoftColor => const Color(0xFFE5F1DD);
  Color get _primaryTextColor => const Color(0xFF1F3516);
  Color get _secondaryTextColor => const Color(0xFF5E7353);
  Color get _warningColor => const Color(0xFFB26A1B);
  Color get _inputFillColor => const Color(0xFFF0F6EB);

  @override
  void initState() {
    super.initState();
    _userId = int.tryParse(_storage.read('user_id')?.toString() ?? '');
    _pendingReservation = _normalizePendingReservation(
      widget.initialReservation,
    );
    _pendingStationName = widget.initialStationName;
    _loadReservations();
    _startRealtimeRefresh();
  }

  @override
  void dispose() {
    _reservationRefreshTimer?.cancel();
    super.dispose();
  }

  ReservationInfo? _normalizePendingReservation(ReservationInfo? reservation) {
    if (reservation == null) {
      return null;
    }

    final int? userId = _userId;
    if (userId == null) {
      return reservation;
    }

    return ReservationInfo(
      reservation_id: reservation.reservation_id,
      user_id: userId,
      station_id: reservation.station_id,
      time: reservation.time,
      is_cancel: reservation.is_cancel,
      imagePath: reservation.imagePath,
    );
  }

  Future<void> _loadReservations() async {
    final int? userId = _userId;
    if (userId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final List<ReservationInfo> reservations = await _api
          .fetchReservationsByUserId(userId: userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _reservations = reservations;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      Get.snackbar('Error', '예약 정보를 불러오지 못했습니다.');
    }
  }

  void _startRealtimeRefresh() {
    _reservationRefreshTimer?.cancel();
    _reservationRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isSubmitting) {
        return;
      }
      _loadReservations();
    });
  }

  Future<void> _confirmPendingReservation() async {
    final ReservationInfo? reservation = _pendingReservation;
    if (reservation == null || _isSubmitting) {
      return;
    }

    if (!reservation.time.isAfter(DateTime.now())) {
      Get.snackbar('Error', '예약 시간은 현재 시각 이후여야 합니다.');
      return;
    }

    final bool alreadyReserved = _reservations.any((ReservationInfo item) {
      return item.station_id == reservation.station_id &&
          item.time.isAtSameMomentAs(reservation.time) &&
          item.is_cancel == 0;
    });
    if (alreadyReserved) {
      Get.snackbar('Error', '같은 대여소와 예약 시각으로 이미 예약이 있습니다.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final int result = await _api.insertReservation(reservation);
      if (result != 1) {
        throw Exception('insert failed');
      }

      await _loadReservations();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingReservation = null;
        _pendingStationName = null;
        _isSubmitting = false;
      });
      Get.snackbar('Success', '예약이 저장되었습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      Get.snackbar('Error', '예약 저장 중 오류가 발생했습니다.');
    }
  }

  Future<void> _deleteReservation(ReservationInfo reservation) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final int result = await _api.deleteReservation(reservation);
      if (result != 1) {
        throw Exception('delete failed');
      }

      await _loadReservations();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      Get.snackbar('Success', '예약이 취소되었습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      Get.snackbar('Error', '예약 취소 중 오류가 발생했습니다.');
    }
  }

  void _selectPendingReservationOffset(int hourOffset) {
    final ReservationInfo? reservation = _pendingReservation;
    if (reservation == null || _isSubmitting) {
      return;
    }
    final DateTime baseTime = DateTime.now().add(Duration(hours: hourOffset));
    final DateTime nextTime = DateTime(
      baseTime.year,
      baseTime.month,
      baseTime.day,
      baseTime.hour,
      baseTime.minute,
    );

    setState(() {
      _pendingReservation = ReservationInfo(
        reservation_id: reservation.reservation_id,
        user_id: reservation.user_id,
        station_id: reservation.station_id,
        time: nextTime,
        is_cancel: reservation.is_cancel,
        imagePath: reservation.imagePath,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final int activeReservationCount = _reservations
        .where((ReservationInfo reservation) => reservation.is_cancel == 0)
        .length;
    final List<Widget> children = <Widget>[
      _buildHeroPanel(context, activeReservationCount),
      const SizedBox(height: 20),
      if (_userId == null)
        _buildEmptyCard(
          context,
          title: '로그인 정보가 없습니다.',
          description: '예약을 진행하려면 먼저 로그인해야 합니다.',
        )
      else ...<Widget>[
        if (_pendingReservation != null) ...<Widget>[
          _buildSectionTitle(context, '진행할 예약'),
          _ReservationCard(
            reservation: _pendingReservation!,
            stationLabel:
                _pendingStationName ?? 'ST-${_pendingReservation!.station_id}',
            statusLabel: '예약 진행중',
            actionLabel: _isSubmitting ? '처리 중...' : '예약 확정',
            secondaryLabel: '예약 취소',
            detail: _PendingReservationEditor(
              reservation: _pendingReservation!,
              onSelectOffset: _selectPendingReservationOffset,
              isSubmitting: _isSubmitting,
            ),
            onSecondaryTap: _isSubmitting
                ? null
                : () => setState(() {
                    _pendingReservation = null;
                    _pendingStationName = null;
                  }),
            onActionTap: _isSubmitting ? null : _confirmPendingReservation,
          ),
          const SizedBox(height: 24),
        ],
        _buildSectionTitle(context, '내 예약'),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reservations.isEmpty)
          _buildEmptyCard(
            context,
            title: '저장된 예약이 없습니다.',
            description: '지도에서 스테이션과 시간대를 선택하면 여기서 예약을 확정할 수 있습니다.',
          )
        else
          ..._reservations.map(
            (ReservationInfo reservation) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ReservationCard(
                reservation: reservation,
                stationLabel: 'ST-${reservation.station_id}',
                statusLabel: reservation.is_cancel == 1 ? '취소됨' : '예약 확정',
                actionLabel: _isSubmitting ? '처리 중...' : '예약 취소',
                secondaryLabel: '새로고침',
                onSecondaryTap: _isSubmitting ? null : _loadReservations,
                onActionTap: _isSubmitting
                    ? null
                    : () => _deleteReservation(reservation),
              ),
            ),
          ),
      ],
    ];

    return RefreshIndicator(
      onRefresh: _loadReservations,
      color: _accentColor,
      backgroundColor: _panelColor,
      child: Container(
        decoration: BoxDecoration(
          color: _pageBackgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _accentSoftColor.withValues(alpha: 0.95),
              _pageBackgroundColor,
              const Color(0xFFEAF4E4),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: children,
        ),
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context, int activeReservationCount) {
    final bool hasPendingReservation = _pendingReservation != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      _accentColor,
                      _accentColor.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event_available,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reservation Hub',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _primaryTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPendingReservation
                          ? '선택한 예약을 검토하고 확정하세요.'
                          : '현재 예약 상태와 확정 내역을 한 번에 관리합니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryChip(
                  icon: Icons.pending_actions,
                  label: '진행중',
                  value: hasPendingReservation ? '1건' : '0건',
                  accent: _warningColor,
                  backgroundColor: const Color(0xFFFFF4E7),
                  textColor: const Color(0xFF7D531D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryChip(
                  icon: Icons.check_circle_outline,
                  label: '확정 예약',
                  value: '$activeReservationCount건',
                  accent: _accentColor,
                  backgroundColor: _inputFillColor,
                  textColor: _primaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: _primaryTextColor,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _secondaryTextColor),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.stationLabel,
    required this.statusLabel,
    required this.actionLabel,
    required this.secondaryLabel,
    required this.onActionTap,
    required this.onSecondaryTap,
    this.detail,
  });

  final ReservationInfo reservation;
  final String stationLabel;
  final String statusLabel;
  final String actionLabel;
  final String secondaryLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onSecondaryTap;
  final Widget? detail;

  Color _statusBackgroundColor() {
    switch (statusLabel) {
      case '예약 진행중':
        return const Color(0xFFFFF3E3);
      case '취소됨':
        return const Color(0xFFF9E8E8);
      default:
        return const Color(0xFFE9F5E3);
    }
  }

  Color _statusTextColor() {
    switch (statusLabel) {
      case '예약 진행중':
        return const Color(0xFF8A5A17);
      case '취소됨':
        return const Color(0xFF9F3C3C);
      default:
        return const Color(0xFF2C6B24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime time = reservation.time;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF49992E).withValues(alpha: 0.12),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        stationLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F3516),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBackgroundColor(),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _statusTextColor(),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: <Widget>[
                      _ReservationRow(
                        label: '예약 일자',
                        value:
                            '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 14),
                      _ReservationRow(
                        label: '예약 시간',
                        value:
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 14),
                      _ReservationRow(label: '대여소', value: stationLabel),
                    ],
                  ),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 16),
                  detail!,
                ],
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3E3),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: onSecondaryTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF355F25),
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
                Center(
                  child: Container(
                    width: 1,
                    height: 25,
                    color: const Color(0xFFD9D9D9),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF355F25),
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingReservationEditor extends StatelessWidget {
  const _PendingReservationEditor({
    required this.reservation,
    required this.onSelectOffset,
    required this.isSubmitting,
  });

  final ReservationInfo reservation;
  final ValueChanged<int> onSelectOffset;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final int selectedOffset = _resolveSelectedOffset(now, reservation.time);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '예약 시간 설정',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F3516),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '현재 시각 기준으로 1시간 후부터 8시간 후까지만 선택할 수 있습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E7353)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(8, (int index) {
              final int hourOffset = index + 1;
              final DateTime targetTime = now.add(Duration(hours: hourOffset));
              return ChoiceChip(
                label: Text(
                  '$hourOffset시간 후\n${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                ),
                selected: selectedOffset == hourOffset,
                labelStyle: TextStyle(
                  color: selectedOffset == hourOffset
                      ? Colors.white
                      : const Color(0xFF355F25),
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF49992E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selectedOffset == hourOffset
                        ? const Color(0xFF49992E)
                        : const Color(0xFFBED5B1),
                  ),
                ),
                onSelected: isSubmitting
                    ? null
                    : (_) => onSelectOffset(hourOffset),
              );
            }),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '선택된 예약 시각: ${reservation.time.year}-${reservation.time.month.toString().padLeft(2, '0')}-${reservation.time.day.toString().padLeft(2, '0')} ${reservation.time.hour.toString().padLeft(2, '0')}:${reservation.time.minute.toString().padLeft(2, '0')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF355F25)),
            ),
          ),
        ],
      ),
    );
  }

  int _resolveSelectedOffset(DateTime now, DateTime reservationTime) {
    for (int hourOffset = 1; hourOffset <= 8; hourOffset++) {
      final DateTime candidate = now.add(Duration(hours: hourOffset));
      if (candidate.year == reservationTime.year &&
          candidate.month == reservationTime.month &&
          candidate.day == reservationTime.day &&
          candidate.hour == reservationTime.hour &&
          candidate.minute == reservationTime.minute) {
        return hourOffset;
      }
    }
    return reservationTime.difference(now).inHours.clamp(1, 8);
  }
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 112,
          child: Text(
            '$label :',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5E7353),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F3516),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.backgroundColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
