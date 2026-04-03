import 'package:beangle_app/view/auth/custom_textfield.dart';
import 'package:beangle_app/view/auth/google_auth_button.dart';
import 'package:beangle_app/view/auth/google_auth_service.dart';
import 'package:beangle_app/widgets/primaryButton.dart';
import 'package:beangle_app/view/auth/auth_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_storage/get_storage.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String trimmed = digits.length > 11
        ? digits.substring(0, 11)
        : digits;

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 3 || i == 7) {
        buffer.write('-');
      }
      buffer.write(trimmed[i]);
    }

    final String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AuthSignPage extends StatefulWidget {
  const AuthSignPage({super.key});

  @override
  State<AuthSignPage> createState() => _AuthSignPageState();
}

class _AuthSignPageState extends State<AuthSignPage> {
  static const String _logoAssetPath = 'images/beangle_logo.png';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final GetStorage _storage = GetStorage();
  final _PhoneNumberFormatter _phoneNumberFormatter = _PhoneNumberFormatter();
  StreamSubscription? _googleAuthSub;
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
            await _sendGoogleAuthToServer(account);
          },
          onError: (_) {
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("구글 가입에 실패했어요.")));
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _googleAuthSub?.cancel();
    super.dispose();
  }

  String? _validateInputs() {
    final name = _nameController.text.trim();
    final phoneRaw = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

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

    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
      return "비밀번호는 영문과 숫자를 함께 포함해주세요.";
    }

    if (password != passwordConfirm) {
      return "비밀번호 확인이 일치하지 않습니다.";
    }

    return null;
  }

  Future<void> _onSignUpPressed() async {
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

    final payload = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "phone": _phoneController.text.trim(),
      "name": _nameController.text.trim(),
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/auth/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final bool success =
            body is Map<String, dynamic> && body["success"] == true;
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("회원가입이 완료됐어요.")));
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) {
            return;
          }
          Get.back();
        } else {
          final String error = body is Map<String, dynamic>
              ? body["error"]?.toString() ?? ""
              : "";
          final String message = error == "email_already_exists"
              ? "이미 가입된 이메일입니다."
              : "회원가입에 실패했어요.";
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입에 실패했어요. (${response.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("서버에 연결할 수 없어요.")));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendGoogleAuthToServer(GoogleSignInAccount account) async {
    final idToken = await _googleAuthService.getIdToken(account);
    if (!mounted) {
      return;
    }
    if (idToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("구글 토큰을 가져올 수 없어요.")));
      return;
    }

    final payload = {
      "email": account.email,
      "name": account.displayName ?? "",
      "idToken": idToken,
    };

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
          if (!mounted) {
            return;
          }
          Get.snackbar('Success', '구글 계정으로 가입됐어요.');
          Get.off(() => const AuthPage());
          return;
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("구글 가입에 실패했어요.")));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("서버에 연결할 수 없어요.")));
    }
  }

  Future<void> _onGoogleSignUpPressed() async {
    try {
      final account = await _googleAuthService.signIn();
      if (!mounted) {
        return;
      }

      if (account == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("가입이 취소됐어요.")));
        return;
      }

      await _sendGoogleAuthToServer(account);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("구글 가입에 실패했어요.")));
    }
  }

  double _logoWidth(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return 260;
    }
    if (screenWidth >= 600) {
      return 210;
    }
    return 140;
  }

  double _fieldGap(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return 18;
    }
    if (screenWidth >= 600) {
      return 16;
    }
    return 12;
  }

  double _sectionGap(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return 30;
    }
    if (screenWidth >= 600) {
      return 26;
    }
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    final double logoWidth = _logoWidth(context);
    final double fieldGap = _fieldGap(context);
    final double sectionGap = _sectionGap(context);
    final bool isWide = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFE5F1DD),
              Color(0xFFF7F8F5),
              Color(0xFFEAF4E4),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: isWide
                  ? Row(
                      children: <Widget>[
                        Expanded(child: _buildIntroPanel(context, logoWidth)),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildFormCard(context, fieldGap, sectionGap),
                        ),
                      ],
                    )
                  : _buildFormCard(context, fieldGap, sectionGap),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroPanel(BuildContext context, double logoWidth) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF49992E),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 28),
          Image.asset(_logoAssetPath, width: logoWidth, fit: BoxFit.contain),
          const SizedBox(height: 28),
          const Text(
            'Beangle 시작하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '회원 정보를 입력하면 지도, 예약, 예측 데이터를 바로 사용할 수 있습니다.',
            style: TextStyle(
              color: Color(0xFFEAF4E4),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(Icons.phone_iphone, '전화번호는 010-0000-0000 형식으로 입력'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.lock_outline, '비밀번호는 영문과 숫자를 함께 포함'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.map_outlined, '가입 후 바로 사용자 지도 화면으로 이동 가능'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    double fieldGap,
    double sectionGap,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '회원가입',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F3516),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '필수 정보를 입력하고 계정을 생성하세요.',
            style: TextStyle(color: Color(0xFF5E7353), height: 1.5),
          ),
          SizedBox(height: sectionGap),
          CustomTextField(
            hint: "이름 입력",
            icon: Icons.person,
            controller: _nameController,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: fieldGap),
          CustomTextField(
            hint: "010-0000-0000",
            icon: Icons.phone,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[_phoneNumberFormatter],
          ),
          SizedBox(height: fieldGap),
          CustomTextField(
            hint: "이메일 입력",
            icon: Icons.email,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: fieldGap),
          CustomTextField(
            hint: "비밀번호 입력",
            icon: Icons.lock,
            obscure: true,
            controller: _passwordController,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: fieldGap),
          CustomTextField(
            hint: "비밀번호 확인",
            icon: Icons.lock_reset,
            obscure: true,
            controller: _passwordConfirmController,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '가입 안내',
                  style: TextStyle(
                    color: Color(0xFF1F3516),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '전화번호는 숫자만 입력해도 자동으로 하이픈이 들어갑니다.',
                  style: TextStyle(color: Color(0xFF5E7353), height: 1.45),
                ),
                SizedBox(height: 4),
                Text(
                  '비밀번호는 6자 이상, 영문과 숫자를 함께 입력해주세요.',
                  style: TextStyle(color: Color(0xFF5E7353), height: 1.45),
                ),
              ],
            ),
          ),
          SizedBox(height: sectionGap),
          PrimaryButton(
            text: _isSubmitting ? "가입 처리 중..." : "회원가입",
            onPressed: _isSubmitting ? () {} : _onSignUpPressed,
          ),
          SizedBox(height: fieldGap),
          const Center(child: Text("또는")),
          SizedBox(height: fieldGap),
          GoogleAuthButton(
            onPressed: _isSubmitting ? () {} : _onGoogleSignUpPressed,
            label: "Google로 가입",
          ),
          SizedBox(height: fieldGap),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                Get.back();
              },
              child: const Text("이미 계정이 있나요? 로그인"),
            ),
          ),
        ],
      ),
    );
  }
}
