import 'package:flutter/material.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.currentPageLabel,
    required this.body,
  });

  final String title;
  final String currentPageLabel;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFeeeeee),
      body: body,
    );
  }
}
