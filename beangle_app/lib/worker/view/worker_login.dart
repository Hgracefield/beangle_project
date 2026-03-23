
import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:beangle_app/worker/view/map_for_worker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class WorkerLogin extends StatefulWidget {
  const WorkerLogin({super.key});

  @override
  State<WorkerLogin> createState() => _WorkerLoginState();
}

class _WorkerLoginState extends State<WorkerLogin> {
  final GetStorage _storage = GetStorage();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String get _workerApiBaseUrl {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  @override
  void initState() {
    super.initState();
  
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return "이메일 형식을 확인해주세요.";
    }
    if (password.trim().isEmpty) {
      return "비밀번호를 입력해주세요.";
    }
    return null;
  }

  Future<void> _onLoginPressed() async {
    final errorMessage = _validateInputs();
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    final payload = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text
    };
    try {
      final response = await http.post(
        Uri.parse("$_workerApiBaseUrl/worker/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> results =
            body is Map<String, dynamic> && body["results"] is List<dynamic>
                ? body["results"] as List<dynamic>
                : <dynamic>[];
        final success =
            body is Map<String, dynamic> &&
            body["success"] == true &&
            results.isNotEmpty;

        if (success) {
          final Map<String, dynamic> workerInfo =
              results.first as Map<String, dynamic>;
          final dynamic workerId = workerInfo['worker_id'];
          if (workerId != null) {
            await _storage.write('worker_id', workerId);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("로그인 성공!")),
          );
          if (!mounted) {
            return;
          }
          Get.to(MapForWorkerPage());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("이메일 또는 비밀번호가 올바르지 않아요.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("로그인에 실패했어요. (${response.statusCode})")),
        );
      }
    } catch (error) {
      debugPrint('worker login error: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버에 연결할 수 없어요.")),
      );
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bike, size: 60, color: Color(0xFF49992E)),
              SizedBox(height: 10),
              Text("빙글 - 관리자", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

              SizedBox(height: 30),

              CustomTextField(
                hint: "이메일 입력",
                icon: Icons.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),

              CustomTextField(
                hint: "비밀번호 입력",
                icon: Icons.lock,
                obscure: true,
                controller: _passwordController,
                textInputAction: TextInputAction.done,
              ),

              SizedBox(height: 20),

              PrimaryButton(
                text: "로그인",
                onPressed: _onLoginPressed,
              ),

            ],
          ),
        ),
      ),
    );
  }
}
