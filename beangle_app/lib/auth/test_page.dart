import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:beangle_app/app_shell.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = GetStorage();
    final userId = storage.read("user_id");

    return AppPageScaffold(
      title: 'Test Page',
      currentRoute: AppRoutes.test,
      body: Center(
        child: Text(
          userId == null ? "user_id 없음" : "user_id: $userId",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
