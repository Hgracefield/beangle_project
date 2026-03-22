import 'package:beangle_app/auth/auth_sign_page.dart';
import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';
import 'package:get/get.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
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
              ),
              SizedBox(height: 16),

              CustomTextField(
                hint: "비밀번호 입력",
                icon: Icons.lock,
                obscure: true,
              ),

              SizedBox(height: 20),

              PrimaryButton(
                text: "로그인",
                onPressed: () {},
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
