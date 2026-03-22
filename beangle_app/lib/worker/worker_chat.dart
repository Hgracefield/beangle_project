import 'package:flutter/material.dart';

class WorkerChatPage extends StatelessWidget {
  const WorkerChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('어드민 채팅'),
      ),
      body: const Center(
        child: Text('Worker Chat Page'),
      ),
    );
  }
}
