import 'package:beangle_app/view/auth/custom_textfield.dart';
import 'package:beangle_app/widgets/primaryButton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

class WorkerAuthSignPage extends StatefulWidget {
  const WorkerAuthSignPage({super.key});

  @override
  State<WorkerAuthSignPage> createState() => _WorkerAuthSignPageState();
}

class _WorkerAuthSignPageState extends State<WorkerAuthSignPage> {
  static const String _logoAssetPath = 'images/beangle_logo.png';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mailCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  bool _isSubmitting = false;
  bool _isAuth = false;
  bool _isMailSending = false;
  bool _isMailVerifying = false;
  bool _mailSent = false;
  String? _verifiedEmail;

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
    _emailController.addListener(_handleEmailChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mailCodeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {
    if (!mounted) {
      return;
    }
    final current = _emailController.text.trim();
    if (_verifiedEmail != null && _verifiedEmail != current) {
      setState(() {
        _isAuth = false;
        _mailSent = false;
        _verifiedEmail = null;
      });
    }
  }

  String? _validateEmailOnly() {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return "이메일 형식을 확인해주세요.";
    }
    return null;
  }

  String? _validateInputs() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (name.isEmpty) {
      return "이름을 입력해주세요.";
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

    final verifiedEmail = _verifiedEmail;
    if (!_isAuth || verifiedEmail == null || verifiedEmail != _emailController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("메일 인증을 완료해주세요.")));
      return;
    }

    final payload = {
      "worker_email": _emailController.text.trim(),
      "worker_password": _passwordController.text,
      "worker_name": _nameController.text.trim(),
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/worker/insert"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final String result =
            body is Map<String, dynamic> ? body["result"]?.toString() ?? "" : "";
        if (result == "OK") {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("회원가입이 완료됐어요.")));
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) {
            return;
          }
          Get.back();
        } else {
          final String message =
              result == "EMAIL_NOT_VERIFIED" ? "메일 인증을 완료해주세요." : "회원가입에 실패했어요.";
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

  Future<void> _onMailAuth() async {
    if (_isMailSending || _isMailVerifying) {
      return;
    }

    final errorMessage = _validateEmailOnly();
    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    setState(() {
      _isMailSending = true;
    });

    try {
      final email = _emailController.text.trim();
      final Uri existUri = Uri.parse("$_authApiBaseUrl/worker/exist")
          .replace(queryParameters: {"email": email});
      final existResponse = await http.get(
        existUri,
        headers: {"Content-Type": "application/json"},
      );

      print(existUri);

      if (!mounted) {
        return;
      }

      if (existResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("메일 확인에 실패했어요. (${existResponse.statusCode})")),
        );
        return;
      }

      final dynamic existBody = jsonDecode(existResponse.body);
      final dynamic existResult =
          existBody is Map<String, dynamic> ? existBody["result"] : null;
      if (existResult == "Error") {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("메일 확인에 실패했어요.")));
        return;
      }

      final int existCount =
          existResult is int ? existResult : int.tryParse(existResult?.toString() ?? "") ?? 0;
      if (existCount > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("이미 가입된 이메일입니다.")));
        return;
      }

      final sendResponse = await http.post(
        Uri.parse("$_authApiBaseUrl/worker/mail-auth/send"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"worker_email": email}),
      );

      if (!mounted) {
        return;
      }

      if (sendResponse.statusCode == 200) {
        final dynamic sendBody = jsonDecode(sendResponse.body);
        final String result =
            sendBody is Map<String, dynamic> ? sendBody["result"]?.toString() ?? "" : "";
        if (result == "OK") {
          setState(() {
            _mailSent = true;
            _isAuth = false;
            _verifiedEmail = null;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("인증 메일을 전송했어요.")));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("메일 전송에 실패했어요.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("메일 전송에 실패했어요. (${sendResponse.statusCode})")),
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
          _isMailSending = false;
        });
      }
    }
  }

  Future<void> _onVerifyMailCode() async {
    if (_isMailVerifying || _isMailSending) {
      return;
    }

    final errorMessage = _validateEmailOnly();
    if (errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    final code = _mailCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("인증번호 6자리를 입력해주세요.")));
      return;
    }

    setState(() {
      _isMailVerifying = true;
    });

    try {
      final email = _emailController.text.trim();
      final response = await http.post(
        Uri.parse("$_authApiBaseUrl/worker/mail-auth/verify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"worker_email": email, "code": code}),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final String result =
            body is Map<String, dynamic> ? body["result"]?.toString() ?? "" : "";
        if (result == "OK") {
          setState(() {
            _isAuth = true;
            _verifiedEmail = email;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("메일 인증이 완료됐어요.")));
        } else if (result == "EXPIRED") {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("인증번호가 만료됐어요. 다시 요청해주세요.")));
        } else if (result == "INVALID") {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("인증번호가 올바르지 않아요.")));
        } else if (result == "NOT_FOUND") {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("인증 요청 내역이 없어요.")));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("메일 인증에 실패했어요.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("메일 인증에 실패했어요. (${response.statusCode})")),
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
          _isMailVerifying = false;
        });
      }
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
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  hint: "이메일 입력",
                  icon: Icons.email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
              ),
              SizedBox(width: fieldGap),
              Expanded(
                child: PrimaryButton(
                  text: _isAuth ? "인증 완료" : "메일 인증",
                  onPressed: _isAuth || _isMailSending ? () {} : _onMailAuth,
                ),
              ),
            ],
          ),
          if (_mailSent && !_isAuth) ...[
            SizedBox(height: fieldGap),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    hint: "인증번호 6자리 입력",
                    icon: Icons.verified_outlined,
                    controller: _mailCodeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                SizedBox(width: fieldGap),
                Expanded(
                  child: PrimaryButton(
                    text: _isMailVerifying ? "확인 중..." : "인증 확인",
                    onPressed: _isMailVerifying ? () {} : _onVerifyMailCode,
                  ),
                ),
              ],
            ),
          ],
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
          // const SizedBox(height: 18),
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF3F7EF),
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: const Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: <Widget>[
          //       Text(
          //         '가입 안내',
          //         style: TextStyle(
          //           color: Color(0xFF1F3516),
          //           fontWeight: FontWeight.w700,
          //         ),
          //       ),
          //       SizedBox(height: 8),
          //       Text(
          //         '전화번호는 숫자만 입력해도 자동으로 하이픈이 들어갑니다.',
          //         style: TextStyle(color: Color(0xFF5E7353), height: 1.45),
          //       ),
          //       SizedBox(height: 4),
          //       Text(
          //         '비밀번호는 6자 이상, 영문과 숫자를 함께 입력해주세요.',
          //         style: TextStyle(color: Color(0xFF5E7353), height: 1.45),
          //       ),
          //     ],
          //   ),
          // ),
          SizedBox(height: sectionGap),
          PrimaryButton(
            text: _isSubmitting ? "가입 처리 중..." : "회원가입",
            onPressed: _isSubmitting ? () {} : _onSignUpPressed,
          ),
        ],
      ),
    );
  }
}
