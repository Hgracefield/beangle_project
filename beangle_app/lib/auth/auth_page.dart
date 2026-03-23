import 'package:beangle_app/auth/auth_sign_page.dart';
import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/google_auth_button.dart';
import 'package:beangle_app/auth/google_auth_service.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:beangle_app/user/map_for_user.dart';
import 'package:beangle_app/worker/view/worker_login.dart';
import 'package:flutter/material.dart';
import 'package:beangle_app/app_shell.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_storage/get_storage.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final GetStorage _storage = GetStorage();
  StreamSubscription? _googleAuthSub;

  String get _authApiBaseUrl {
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
    if (kIsWeb) {
      _googleAuthService.initialize().then((_) {
        _googleAuthSub = _googleAuthService.authenticationEvents.listen(
          (event) async {
            if (!mounted) {
              return;
            }
            if (event is! GoogleSignInAuthenticationEventSignIn) {
              return;
            }
            final account = event.user;
            await _sendGoogleAuthToServer(account, isSignUp: false);
          },
          onError: (_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("구글 로그인에 실패했어요.")));
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _googleAuthSub?.cancel();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    final payload = {"email": _emailController.text.trim(), "password": _passwordController.text, "phone": "", "name": ""};

    try {
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/auth/login"),
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
          final userId = body["user_id"];
          if (userId != null) {
            await _storage.write("user_id", userId);
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("로그인 성공!")));
          if (!mounted) {
            return;
          }
          Get.to(MapForUserPage());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("이메일 또는 비밀번호가 올바르지 않아요.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("로그인에 실패했어요. (${response.statusCode})")));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("서버에 연결할 수 없어요.")));
    }
  }

  Future<void> _sendGoogleAuthToServer(GoogleSignInAccount account, {required bool isSignUp}) async {
    final idToken = await _googleAuthService.getIdToken(account);
    if (!mounted) {
      return;
    }
    if (idToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("구글 토큰을 가져올 수 없어요.")));
      return;
    }

    final payload = {"email": account.email, "name": account.displayName ?? "", "idToken": idToken};

    try {
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/auth/google_login"),
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
          final userId = body["user_id"];
          if (userId != null) {
            await _storage.write("user_id", userId);
          }
          final message = isSignUp ? "구글 가입 완료!" : "구글 로그인 완료!";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          if (!mounted) {
            return;
          }
          Get.to(MapForUserPage());
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("구글 로그인에 실패했어요.")));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("서버에 연결할 수 없어요.")));
    }
  }

  Future<void> _onGoogleLoginPressed() async {
    try {
      final account = await _googleAuthService.signIn();
      if (!mounted) {
        return;
      }

      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("로그인이 취소됐어요.")));
        return;
      }

      await _sendGoogleAuthToServer(account, isSignUp: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("구글 로그인에 실패했어요.")));
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
              GestureDetector(
                onTap: () {
                  Get.to(WorkerLogin());
                },
                child: Icon(Icons.directions_bike, size: 60, color: Color(0xFF49992E))),
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

              PrimaryButton(text: "로그인", onPressed: _onLoginPressed),

              SizedBox(height: 16),
              Text("또는"),

              SizedBox(height: 16),

              GoogleAuthButton(onPressed: _onGoogleLoginPressed, label: "Google로 로그인"),

              SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Get.to(AuthSignPage());
                },
                child: Text("회원가입"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
