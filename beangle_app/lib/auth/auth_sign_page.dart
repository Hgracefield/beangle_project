import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class AuthSignPage extends StatelessWidget {
  const AuthSignPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Sign Up',
      currentRoute: AppRoutes.authSign,
      body: Center(child: Text('Auth Sign Page')),
    );
  }
}
