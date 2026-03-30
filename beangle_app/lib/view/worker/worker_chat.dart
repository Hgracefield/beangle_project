import 'package:beangle_app/view/worker/worker_theme.dart';
import 'package:flutter/material.dart';

class WorkerChatPage extends StatelessWidget {
  const WorkerChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: workerThemeColor,
        foregroundColor: Colors.white,
        title: const Text('어드민 채팅'),
      ),
      body: const Center(
        child: Text('Worker Chat Page'),
      ),
    );
  }
}
