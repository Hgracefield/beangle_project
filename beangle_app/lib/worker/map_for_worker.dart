import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class MapForWorkerPage extends StatelessWidget {
  const MapForWorkerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'Worker Map',
      currentRoute: AppRoutes.workerMap,
      body: Center(child: Text('Map For Worker Page')),
    );
  }
}
