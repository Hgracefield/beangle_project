import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class MapForUserPage extends StatelessWidget {
  const MapForUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'User Map',
      currentRoute: AppRoutes.userMap,
      body: Center(child: Text('Map For User Page')),
    );
  }
}
