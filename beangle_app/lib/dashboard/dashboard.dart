import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Dashboard',
      currentRoute: AppRoutes.dashboard,
      body: Center(child: Text('Dashboard Page')),
    );
  }
}
