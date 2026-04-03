import 'dart:convert';

import 'package:beangle_app/view/auth/custom_textfield.dart';
import 'package:beangle_app/widgets/primaryButton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthFindInfoPage extends StatefulWidget {
  const AuthFindInfoPage({super.key});

  @override
  State<AuthFindInfoPage> createState() => _AuthFindInfoPageState();
}

class _AuthFindInfoPageState extends State<AuthFindInfoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF49992E),
        foregroundColor: Colors.white,
        title: const Text(
          '아이디 / 비밀번호 찾기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Tab>[
            Tab(text: '아이디 찾기'),
            Tab(text: '비밀번호 재설정'),
          ],
        ),
      ),
      body: Center(
        child: Container(
          width: 460,
          margin: const EdgeInsets.all(24),
          child: TabBarView(
            controller: _tabController,
            children: const <Widget>[_FindIdTab(), _ResetPasswordTab()],
          ),
        ),
      ),
    );
  }
}

class _FindIdTab extends StatefulWidget {
  const _FindIdTab();

  @override
  State<_FindIdTab> createState() => _FindIdTabState();
}

class _FindIdTabState extends State<_FindIdTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _resultEmail;

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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final String name = _nameController.text.trim();
    final String phoneDigits = _phoneController.text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (name.isEmpty) {
      return '이름을 입력해주세요.';
    }
    if (phoneDigits.length < 9) {
      return '전화번호를 확인해주세요.';
    }
    return null;
  }

  Future<void> _findId() async {
    final String? validationError = _validateInputs();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _isLoading = true;
      _resultEmail = null;
    });

    try {
      final http.Response response = await http.post(
        Uri.parse('$_authApiBaseUrl/auth/find-id'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          _resultEmail =
              body['masked_email']?.toString() ??
              body['email']?.toString() ??
              '';
        });
        return;
      }

      throw Exception(body['error']?.toString() ?? 'user_not_found');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일치하는 회원 정보를 찾지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      title: '가입한 이메일 찾기',
      description: '가입할 때 사용한 이름과 전화번호를 입력해주세요.',
      children: <Widget>[
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
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          text: _isLoading ? '조회 중...' : '아이디 찾기',
          onPressed: _isLoading ? () {} : _findId,
        ),
        const SizedBox(height: 24),
        if (_resultEmail != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4E4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '가입된 이메일: $_resultEmail',
              style: const TextStyle(
                color: Color(0xFF1F3516),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResetPasswordTab extends StatefulWidget {
  const _ResetPasswordTab();

  @override
  State<_ResetPasswordTab> createState() => _ResetPasswordTabState();
}

class _ResetPasswordTabState extends State<_ResetPasswordTab> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _isVerified = false;

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
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  String? _validateIdentityInputs() {
    final String email = _emailController.text.trim();
    final String name = _nameController.text.trim();
    final String phoneDigits = _phoneController.text.replaceAll(
      RegExp(r'\D'),
      '',
    );
    final RegExp emailRegex = RegExp(r'^[^@\s]+@[^\s]+\.[^\s]+$');

    if (!emailRegex.hasMatch(email)) {
      return '이메일 형식을 확인해주세요.';
    }
    if (name.isEmpty) {
      return '이름을 입력해주세요.';
    }
    if (phoneDigits.length < 9) {
      return '전화번호를 확인해주세요.';
    }
    return null;
  }

  String? _validatePasswordInputs() {
    final String password = _passwordController.text;
    final String passwordConfirm = _passwordConfirmController.text;

    if (password.trim().length < 6) {
      return '비밀번호는 6자 이상 입력해주세요.';
    }
    if (password != passwordConfirm) {
      return '비밀번호 확인이 일치하지 않습니다.';
    }
    return null;
  }

  Future<void> _verifyIdentity() async {
    final String? validationError = _validateIdentityInputs();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isVerified = false;
    });

    try {
      final http.Response response = await http.post(
        Uri.parse('$_authApiBaseUrl/auth/verify-user-for-password-reset'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('본인 확인이 완료됐어요. 새 비밀번호를 입력해주세요.')),
        );
        return;
      }

      throw Exception(body['error']?.toString() ?? 'user_not_found');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력한 정보와 일치하는 회원을 찾지 못했어요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final String? identityError = _validateIdentityInputs();
    if (identityError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(identityError)));
      return;
    }

    final String? passwordError = _validatePasswordInputs();
    if (passwordError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(passwordError)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final http.Response response = await http.post(
        Uri.parse('$_authApiBaseUrl/auth/reset-password'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'new_password': _passwordController.text,
        }),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호가 재설정됐어요.')));
        Navigator.of(context).pop();
        return;
      }

      throw Exception(body['error']?.toString() ?? 'password_reset_failed');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정에 실패했어요.')));
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
    return _AuthCard(
      title: '비밀번호 재설정',
      description: '가입한 이메일, 이름, 전화번호로 본인 확인 후 새 비밀번호를 설정합니다.',
      children: <Widget>[
        CustomTextField(
          hint: '이메일 입력',
          icon: Icons.email,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
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
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          text: _isSubmitting ? '확인 중...' : '본인 확인',
          onPressed: _isSubmitting ? () {} : _verifyIdentity,
        ),
        const SizedBox(height: 24),
        if (_isVerified) ...<Widget>[
          CustomTextField(
            hint: '새 비밀번호 입력',
            icon: Icons.lock,
            obscure: true,
            controller: _passwordController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hint: '새 비밀번호 확인',
            icon: Icons.lock_reset,
            obscure: true,
            controller: _passwordConfirmController,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: _isSubmitting ? '재설정 중...' : '비밀번호 재설정',
            onPressed: _isSubmitting ? () {} : _resetPassword,
          ),
        ],
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F3516),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF5E7353), height: 1.5),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
