import 'package:beangle_app/settings/local_notification.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';
import 'package:beangle_app/auth/auth_find_info.dart';
import 'package:beangle_app/auth/auth_page.dart';
import 'package:beangle_app/auth/auth_sign_page.dart';
import 'package:beangle_app/dashboard/dashboard.dart';
import 'package:beangle_app/reservation/reservation.dart';
import 'package:beangle_app/user/map_for_user.dart';
import 'package:beangle_app/worker/map_for_worker.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Seoul Bike Prediction',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.auth,
      routes: AppRoutes.routeMap,
    );
  }
}
