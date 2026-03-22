import 'package:beangle_app/app_shell.dart';
import 'package:beangle_app/reservation/model/reservation_api.dart';
import 'package:beangle_app/reservation/model/reservation_info.dart';
import 'package:beangle_app/reservation/widgets/illu_widget.dart';
import 'package:beangle_app/reservation/widgets/reservation_card_widget.dart';
import 'package:flutter/material.dart';

class ReservationPage extends StatelessWidget {
  const ReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '예약 현황',
      currentRoute: AppRoutes.reservation,
      body: const _ReservationView(),
    );
  }
}

class _ReservationView extends StatefulWidget {
  const _ReservationView();

  @override
  State<_ReservationView> createState() => _ReservationViewState();
}

class _ReservationViewState extends State<_ReservationView> {
  late final Future<ReservationInfo> _reservationFuture;

  @override
  void initState() {
    super.initState();
    _reservationFuture = ReservationApi().fetchReservation();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReservationInfo>(
      future: _reservationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Text(
                '\uC608\uC57D \uB300\uC5EC \uD6C4 \uB300\uC5EC\uC2DC\uAC04 \uC548\uC5D0 \uC815\uC0C1 \uBC18\uB0A9\uC2DC 24\uC2DC\uAC04 \uB3D9\uC548\uC740 \uB300\uC5EC\uD69F\uC218 \uC81C\uD55C\uC5C6\uC774 \uC608\uC57D\uAC00\uB2A5.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 12),
              ),
            ),
          );
        }

        final reservation = snapshot.data ?? ReservationInfo.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NoticeBanner(
                message: reservation.notice,
                textStyle: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF555555),
                    ),
              ),

              const SizedBox(height: 18),
              ReservationCardWidget(reservation: reservation),
              const SizedBox(height: 28),
              IlluWidget(imagePath: reservation.imagePath),
            ],
          ),
        );
      },
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, this.textStyle});

  final String message;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style:
          textStyle ??
          Theme.of(context).textTheme.titleMedium?.copyWith(
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
