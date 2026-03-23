import 'dart:convert';

import 'package:beangle_app/auth/custom_textfield.dart';
import 'package:beangle_app/auth/primaryButton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  static const String _userIdStorageKey = 'user_id';

  final GetStorage _storage = GetStorage();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

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
    _userId = _storage.read(_userIdStorageKey)?.toString();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final String? userId = _userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final http.Response response = await http.get(
        Uri.parse('$_authApiBaseUrl/users/$userId'),
      );

      if (response.statusCode != 200) {
        throw Exception('failed_to_load_profile');
      }

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic>? user = body['user'] as Map<String, dynamic>?;

      if (body['success'] != true || user == null) {
        throw Exception('invalid_profile_payload');
      }

      _nameController.text = user['name']?.toString() ?? '';
      _phoneController.text = user['phone']?.toString() ?? '';
      _emailController.text = user['email']?.toString() ?? '';
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('개인정보를 불러오지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateInputs() {
    final String name = _nameController.text.trim();
    final String phoneRaw = _phoneController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (name.isEmpty) {
      return '이름을 입력해주세요.';
    }

    final String phoneDigits = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 9) {
      return '전화번호를 확인해주세요.';
    }

    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return '이메일 형식을 확인해주세요.';
    }

    if (password.trim().isNotEmpty && password.trim().length < 6) {
      return '비밀번호는 6자 이상 입력해주세요.';
    }

    return null;
  }

  Future<void> _saveProfile() async {
    final String? userId = _userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보가 없습니다.')));
      return;
    }

    final String? validationError = _validateInputs();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final Map<String, String> payload = <String, String>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
    };

    try {
      final http.Response response = await http.put(
        Uri.parse('$_authApiBaseUrl/users/$userId'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        final String error =
            body['error']?.toString() ?? 'failed_to_update_profile';
        throw Exception(error);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('개인정보가 수정됐어요.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('개인정보 수정 실패: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('개인정보 수정 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
          '개인정보 수정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.manage_accounts,
                        size: 60,
                        color: Color(0xFF49992E),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '개인정보 수정',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      CustomTextField(
                        hint: '이름 입력',
                        icon: Icons.person,
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        hint: '전화번호 입력',
                        icon: Icons.phone,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        hint: '이메일 입력',
                        icon: Icons.email,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        hint: '새 비밀번호 입력(선택)',
                        icon: Icons.lock,
                        controller: _passwordController,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '비밀번호를 비워두면 기존 비밀번호를 유지합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: _isSaving ? '저장 중...' : '개인정보 저장',
                        onPressed: _isSaving ? () {} : _saveProfile,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
