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
      appBar: AppBar(
        title: const Text('홈'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text('${user?.nickname ?? '사용자'}님, 오늘도 학습해볼까요?'),
                subtitle: const Text('AI가 맞춤형 문제를 생성해드립니다.'),
              ),
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '학습 진행률',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            StudyProgressBar(progress: learningProvider.progress),
            const SizedBox(height: 30),

            _HomeMenuButton(
              title: '단계별 학습 시작',
              subtitle: '듀오링고처럼 레벨별로 학습하기',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.lessons);
              },
            ),
            _HomeMenuButton(
              title: '자료 업로드',
              subtitle: 'PDF/PPT 기반 문제 생성',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.materials);
              },
            ),
            _HomeMenuButton(
              title: '오답노트',
              subtitle: '틀린 문제 다시 풀기',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.review);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMenuButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeMenuButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}