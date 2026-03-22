import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';

class AuthSignPage extends StatelessWidget {
  const AuthSignPage({super.key});

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
                hint: "전화번호 입력",
                icon: Icons.phone,
              ),
              SizedBox(height: 16),

              CustomTextField(
                hint: "이메일 입력",
                icon: Icons.email,
              ),
              SizedBox(height: 16),

              CustomTextField(
                hint: "비밀번호 입력",
                icon: Icons.lock,
                obscure: true,
              ),

              SizedBox(height: 20),

              PrimaryButton(
                text: "회원가입",
                onPressed: () {},
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