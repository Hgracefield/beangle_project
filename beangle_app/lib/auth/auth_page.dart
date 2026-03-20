import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Auth Page',
      currentRoute: AppRoutes.auth,
      body: Center(child: Text('Auth Page')),
    );
  }
}
