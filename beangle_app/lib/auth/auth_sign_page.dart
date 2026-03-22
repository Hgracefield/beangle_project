import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthSignPage extends StatefulWidget {
  const AuthSignPage({super.key});

  @override
  State<AuthSignPage> createState() => _AuthSignPageState();
}

class _AuthSignPageState extends State<AuthSignPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final name = _nameController.text.trim();
    final phoneRaw = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      return "이름을 입력해주세요.";
    }

    final phoneDigits = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 9) {
      return "전화번호를 확인해주세요.";
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return "이메일 형식을 확인해주세요.";
    }

    if (password.trim().length < 6) {
      return "비밀번호는 6자 이상 입력해주세요.";
    }

    return null;
  }

  Future<void> _onSignUpPressed() async {
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
      "phone": _phoneController.text.trim(),
      "name": _nameController.text.trim()
    };

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입이 완료됐어요.")),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          return;
        }
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입에 실패했어요. (${response.statusCode})")),
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
      title: 'Sign Up',
      currentRoute: AppRoutes.authSign,
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bike, size: 60, color: Color(0xFF2E7D32)),
              SizedBox(height: 10),
              Text("회원가입", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

              SizedBox(height: 30),

              CustomTextField(
                hint: "이름 입력",
                icon: Icons.person,
                controller: _nameController,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),

              CustomTextField(
                hint: "전화번호 입력",
                icon: Icons.phone,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 16),

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
                text: "회원가입",
                onPressed: _onSignUpPressed,
              ),

              SizedBox(height: 16),
              Text("또는"),

              SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.login),
                label: Text("Google로 가입"),
              ),

              SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("이미 계정이 있나요? 로그인"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
