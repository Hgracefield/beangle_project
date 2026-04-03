import 'dart:convert';

import 'package:beangle_app/view/auth/custom_textfield.dart';
import 'package:beangle_app/widgets/primaryButton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WorkerFindPassword extends StatefulWidget {
  const WorkerFindPassword({super.key});

  @override
  State<WorkerFindPassword> createState() => _WorkerFindPasswordState();
}

class _WorkerFindPasswordState extends State<WorkerFindPassword> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  String get _authApiBaseUrl {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty) {
      return "이름을 입력해주세요.";
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return "이메일 형식을 확인해주세요.";
    }
    return null;
  }

  Future<void> _onPasswordReset() async {
    if (_isSubmitting) {
      return;
    }

    final errorMessage = _validateInputs();
    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/worker/password-reset"),
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode({
          "worker_email": _emailController.text.trim(),
          "worker_name": _nameController.text.trim(),
        }),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final bool success = body is Map<String, dynamic> &&
            (body["result"]?.toString() == "OK" || body["success"] == true);
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("임시 비밀번호를 메일로 보냈어요.")));
          return;
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("임시 비밀번호 발급에 실패했어요.")));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("서버에 연결할 수 없어요.")));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF49992E),
        foregroundColor: Colors.white,
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          width: 460,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '임시 비밀번호 발급',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F3516),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '가입한 이메일과 이름을 입력하면 임시 비밀번호를 메일로 보내드려요.',
                style: TextStyle(color: Color(0xFF5E7353), height: 1.5),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                hint: "이메일 입력",
                icon: Icons.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: "이름 입력",
                icon: Icons.person,
                controller: _nameController,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: _isSubmitting ? "발급 중..." : "임시 비밀번호 받기",
                onPressed: _isSubmitting ? () {} : _onPasswordReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
