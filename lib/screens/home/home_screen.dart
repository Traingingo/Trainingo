import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/progress/progress_bar.dart';
import '../../providers/learning_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final learningProvider = context.watch<LearningProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA), // 듀오링고풍 깔끔한 배경색
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false, // 홈 화면이므로 뒤로가기 버튼 제거
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 왼쪽: 유저 닉네임 아바타
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF58CC02),
                  child: Text('🎓', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
                Text(
                  user?.nickname ?? '사용자',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B4B4B),
                  ),
                ),
              ],
            ),
            // 오른쪽: 듀오링고식 대시보드 스탯 (불꽃 & 보석 오프셋 연출)
            Row(
              children: [
                _buildStatItem('🔥', '3', Colors.orange),
                const SizedBox(width: 12),
                _buildStatItem('💎', '120', Colors.cyan),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. AI 부엉이 웰컴 말풍선 위젯
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: Row(
                children: [
                  const Text('🦉', style: TextStyle(fontSize: 38)), // AI 마스코트 느낌
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${user?.nickname ?? '사용자'}님, 오늘도 학점 방어하러 가볼까요? 벼락치기 고고! 🔥',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B4B4B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. 학습 진행률 코너 (기존 StudyProgressBar 재사용)
            const Text(
              '현재 학점 방어율',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: Column(
                children: [
                  StudyProgressBar(progress: learningProvider.progress),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('완료도', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(
                        '${(learningProvider.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF58CC02)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. 메인 타이틀
            const Text(
              '오늘의 미션 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 14),

            // 4. 리디자인된 듀오링고풍 입체 메뉴 버튼들
            _HomeMenuButton(
              title: '단계별 학습 시작',
              subtitle: '듀오링고처럼 레벨별로 학습하기',
              icon: '🚀',
              primaryColor: const Color(0xFF58CC02), // 듀오링고 초록
              onTap: () => Navigator.pushNamed(context, AppRoutes.lessons),
            ),
            const SizedBox(height: 14),

            _HomeMenuButton(
              title: '자료 업로드',
              subtitle: 'PDF/PPT 기반 문제 생성',
              icon: '📂',
              primaryColor: const Color(0xFF1CB0F6), // 하늘색 파트
              onTap: () => Navigator.pushNamed(context, AppRoutes.materials),
            ),
            const SizedBox(height: 14),

            _HomeMenuButton(
              title: '오답노트',
              subtitle: '틀린 문제 다시 풀기',
              icon: '📝',
              primaryColor: const Color(0xFFFF9600), // 오렌지색 파트
              onTap: () => Navigator.pushNamed(context, AppRoutes.review),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 스탯 아이템 빌더
  Widget _buildStatItem(String emoji, String count, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// 듀오링고 특유의 하단 그림자가 들어간 입체 메뉴 버튼
class _HomeMenuButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const _HomeMenuButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
          boxShadow: const [
            // 버튼 하단에 도톰한 그림자를 줘서 딸깍 누르고 싶게 만드는 효과
            BoxShadow(
              color: Color(0xFFE5E5E5),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(icon, style: const TextStyle(fontSize: 30)),
          ],
        ),
      ),
    );
  }
}