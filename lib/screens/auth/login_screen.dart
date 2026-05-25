import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoginMode = true; // true: 로그인, false: 회원가입
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final nickname = _nicknameController.text.trim();

    try {
      if (_isLoginMode) {
        await authProvider.login(email, password);
      } else {
        await authProvider.register(email, password, nickname);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      
      // 에러 메시지 한글 정제
      String errorMsg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg.isEmpty ? '요청에 실패했습니다. 다시 시도해 주세요.' : errorMsg,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. 앱 로고 및 타이틀
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF58CC02),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trainingo AI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF58CC02),
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'AI가 만드는 나만의 듀오링고 학습 코스',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. 로그인/회원가입 카드 영역
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 로그인 / 회원가입 전환 탭
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isLoginMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _isLoginMode
                                            ? const Color(0xFF58CC02)
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '로그인',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: _isLoginMode
                                          ? const Color(0xFF58CC02)
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isLoginMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: !_isLoginMode
                                            ? const Color(0xFF58CC02)
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '회원가입',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: !_isLoginMode
                                          ? const Color(0xFF58CC02)
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 이메일 입력창
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: '이메일 주소',
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF7F8FA),
                            contentPadding: const EdgeInsets.all(16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return '이메일을 입력해 주세요.';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                              return '올바른 이메일 형식이 아닙니다.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 비밀번호 입력창
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F8FA),
                            contentPadding: const EdgeInsets.all(16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return '비밀번호를 입력해 주세요.';
                            if (val.length < 4) return '비밀번호는 최소 4글자 이상이어야 합니다.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 닉네임 입력창 (회원가입 모드일 때만 노출)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: !_isLoginMode
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TextFormField(
                                    controller: _nicknameController,
                                    decoration: InputDecoration(
                                      labelText: '닉네임',
                                      hintText: '닉네임을 입력해 주세요',
                                      prefixIcon: const Icon(Icons.face_outlined),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F8FA),
                                      contentPadding: const EdgeInsets.all(16),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (!_isLoginMode && (val == null || val.trim().isEmpty)) {
                                        return '닉네임을 입력해 주세요.';
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        // 제출 버튼
                        if (authProvider.isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                              ),
                            ),
                          )
                        else
                          DuoButton(
                            text: _isLoginMode ? '로그인하기' : '회원가입 및 시작하기',
                            color: const Color(0xFF58CC02),
                            shadowColor: const Color(0xFF46A302),
                            onPressed: _submit,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}