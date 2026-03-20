import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class AuthFindInfoPage extends StatelessWidget {
  const AuthFindInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Find Info',
      currentRoute: AppRoutes.authFindInfo,
      body: Center(child: Text('Auth Find Info Page')),
    );
  }
}
