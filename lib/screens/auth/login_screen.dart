import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'test@test.com');
  final passwordController = TextEditingController(text: '1234');

  // 주황색 메인 테마 컬러 세팅
  final Color orangeThemeColor = const Color(0xFFE67E22); // 세련된 오렌지 컬러

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white, // 배경을 깔끔한 화이트로 고정
      body: Padding(
        padding: const EdgeInsets.all(32), // 여백을 살짝 넓혀서 시원하게 배치
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. 앱 이름 Trainingo로 변경 및 주황색 커스텀 스타일 적용
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Trainingo',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.black,
                        color: orangeThemeColor,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.school, color: orangeThemeColor, size: 36), // 학사모 아이콘 추가로 포인트
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '나만의 개인 맞춤형 AI 트레이너',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500
                  ),
                ),
                const SizedBox(height: 48),

                // 2. 이메일 입력창 (주황색 테두리 적용)
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: '이메일',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: orangeThemeColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. 비밀번호 입력창 (주황색 테두리 적용)
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: orangeThemeColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 4. 로그인 버튼 및 로딩 로직 (기존 커스텀 버튼에 Theme 적용 시도하거나 래핑)
                if (authProvider.isLoading)
                  CircularProgressIndicator(color: orangeThemeColor)
                else
                  Theme(
                    data: Theme.of(context).copyWith(
                      elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orangeThemeColor, // 주황색 버튼색 강제 주입
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    child: CustomButton(
                      text: '로그인',
                      onPressed: () async {
                        await authProvider.login(
                          emailController.text,
                          passwordController.text,
                        );

                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(context, AppRoutes.home);
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                // 5. 아까 요청한 한글화 하단 링크 추가
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text(
                          '비밀번호 찾기',
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)
                      ),
                    ),
                    Text('|', style: TextStyle(color: Colors.grey[300])),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                          '회원가입',
                          style: TextStyle(color: orangeThemeColor, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}