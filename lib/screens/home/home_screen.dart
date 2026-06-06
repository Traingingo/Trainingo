import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question_generation_mode.dart';
import '../../models/question_setup_config.dart';
import '../../models/learning_level.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LearningProvider>().fetchUserSessions(user.id);
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  void _openQuestionSetup() {
    final topic = _subjectController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배우고 싶은 주제를 먼저 입력해 주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.questionSetup,
      arguments: QuestionSetupArguments(topic: topic),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final learningProvider = context.watch<LearningProvider>();
    final recentSessions = learningProvider.userSessions.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, color: Color(0xFF58CC02)),
            SizedBox(width: 8),
            Text(
              'Trainingo AI',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF58CC02),
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF58CC02),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Center(child: Icon(Icons.smart_toy, size: 44, color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                      ),
                      child: Text(
                        '안녕, ${user?.nickname ?? '학습자'}!\n주제를 입력한 뒤 문제 생성 방식과 수준을 골라 맞춤 학습을 시작해 봐.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C3C3C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _StartLearningCard(
                controller: _subjectController,
                onGenerate: _openQuestionSetup,
                onUpload: () => Navigator.pushNamed(context, AppRoutes.materials),
              ),
              const SizedBox(height: 24),
              _MaterialShortcutCard(
                onUpload: () => Navigator.pushNamed(context, AppRoutes.materials),
              ),
              if (recentSessions.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text(
                  '최근 학습',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                ),
                const SizedBox(height: 12),
                ...recentSessions.map((session) {
                  return _RecentSessionCard(
                    subject: session['subject']?.toString() ?? '이름 없는 학습',
                    progress: _toDouble(session['progress']),
                    generationMode: QuestionGenerationModeX.fromApiValue(session['generation_mode']).label,
                    difficulty: LearningLevelX.fromApiValue(session['difficulty']).label,
                    onContinue: () {
                      context.read<LearningProvider>().loadSession(session);
                      Navigator.pushNamed(context, AppRoutes.lessons);
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StartLearningCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onGenerate;
  final VoidCallback onUpload;

  const _StartLearningCard({
    required this.controller,
    required this.onGenerate,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '새로운 주제 학습 생성',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
          ),
          const SizedBox(height: 8),
          const Text(
            '주제 입력 후 다음 화면에서 문제 생성 방식과 학습 수준을 선택합니다.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '예: Flutter 상태관리, 데이터베이스 정규화',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DuoButton(
            text: '문제 생성 설정하기',
            color: const Color(0xFF58CC02),
            shadowColor: const Color(0xFF46A302),
            icon: Icons.tune,
            onPressed: onGenerate,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('자료 추가 후 학습 생성'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1899D6),
              side: const BorderSide(color: Color(0xFF1899D6), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialShortcutCard extends StatelessWidget {
  final VoidCallback onUpload;

  const _MaterialShortcutCard({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onUpload,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF8FF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFB9E3FF), width: 2),
        ),
        child: const Row(
          children: [
            Icon(Icons.description_outlined, color: Color(0xFF1899D6), size: 34),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('업로드한 자료 기반 학습', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF3C3C3C))),
                  SizedBox(height: 4),
                  Text('PDF, PPTX, TXT 자료를 추가한 뒤 자료 기반 또는 혼합 생성으로 문제를 만들 수 있어요.', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF1899D6)),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  final String subject;
  final double progress;
  final String generationMode;
  final String difficulty;
  final VoidCallback onContinue;

  const _RecentSessionCard({
    required this.subject,
    required this.progress,
    required this.generationMode,
    required this.difficulty,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipLabel(label: generationMode, color: const Color(0xFF1899D6)),
              _ChipLabel(label: difficulty, color: const Color(0xFF58CC02)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E5E5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.play_arrow),
              label: const Text('이어서 학습하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
    );
  }
}
