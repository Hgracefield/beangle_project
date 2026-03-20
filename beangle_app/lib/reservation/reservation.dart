import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class ReservationPage extends StatelessWidget {
  const ReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Reservation',
      currentRoute: AppRoutes.reservation,
      body: Center(child: Text('Reservation Page')),
    );
  }
}
