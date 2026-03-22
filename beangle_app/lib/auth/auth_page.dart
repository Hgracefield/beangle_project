import 'package:beangle_app/auth/auth_sign_page.dart';
import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
      "password": _passwordController.text,
      "phone": "",
      "name":""
    };

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final success = body is Map<String, dynamic> && body["success"] == true;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("로그인 성공!")),
          );
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
    } catch (_) {
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
    return AppPageScaffold(
      title: 'Auth Page',
      currentRoute: AppRoutes.auth,
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bike, size: 60, color: Color(0xFF2E7D32)),
              SizedBox(height: 10),
              Text("빙글", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

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

              SizedBox(height: 16),
              Text("또는"),

              SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.login),
                label: Text("Google로 로그인"),
              ),

              SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Get.to(AuthSignPage());
                },
                child: Text("회원가입"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
