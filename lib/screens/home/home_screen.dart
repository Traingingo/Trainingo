import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_setup_options.dart';
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
  final TextEditingController _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) context.read<LearningProvider>().fetchUserSessions(user.id);
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _openSetup(QuestionGenerationMode mode) {
    final topic = _topicController.text.trim();
    Navigator.pushNamed(
      context,
      AppRoutes.quizSetup,
      arguments: QuizSetupArgs(topic: topic, initialMode: mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final sessions = context.watch<LearningProvider>().userSessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: Color(0xFF58CC02)),
            SizedBox(width: 8),
            Text('Trainingo AI', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF58CC02))),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final currentUser = context.read<AuthProvider>().user;
          if (currentUser != null) await context.read<LearningProvider>().fetchUserSessions(currentUser.id);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _GreetingCard(nickname: user?.nickname ?? '학습자'),
            const SizedBox(height: 22),
            _CreateLearningCard(
              controller: _topicController,
              onAiOnly: () => _openSetup(QuestionGenerationMode.aiOnly),
              onMaterialOnly: () => _openSetup(QuestionGenerationMode.materialOnly),
              onMixed: () => _openSetup(QuestionGenerationMode.mixed),
              onUpload: () => Navigator.pushNamed(context, AppRoutes.materials),
            ),
            const SizedBox(height: 24),
            if (sessions.isNotEmpty) ...[
              const Text('최근 학습', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
              const SizedBox(height: 12),
              ...sessions.take(3).map((session) => _RecentSessionTile(session: session)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final String nickname;

  const _GreetingCard({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: const Color(0xFF58CC02), borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 42),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '안녕, $nickname!\n문제 생성 전에 방식과 수준을 먼저 고르면 더 맞춤형으로 출제할 수 있어요.',
              style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateLearningCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAiOnly;
  final VoidCallback onMaterialOnly;
  final VoidCallback onMixed;
  final VoidCallback onUpload;

  const _CreateLearningCard({
    required this.controller,
    required this.onAiOnly,
    required this.onMaterialOnly,
    required this.onMixed,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('주제 학습 생성', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 8),
          const Text('여기서는 주제만 간단히 입력하고, 다음 화면에서 생성 방식과 수준을 선택합니다.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, height: 1.35)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '예: 모바일 프로그래밍, SQL 조인, Flutter Provider',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2)),
            ),
          ),
          const SizedBox(height: 18),
          DuoButton(text: '문제 생성 설정하기', icon: Icons.tune_rounded, onPressed: onAiOnly),
          const SizedBox(height: 12),
          DuoButton(
            text: '자료 추가',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF1899D6),
            shadowColor: const Color(0xFF147EA9),
            onPressed: onUpload,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniModeButton(label: '자료 기반 생성', icon: Icons.description_rounded, onTap: onMaterialOnly)),
              const SizedBox(width: 10),
              Expanded(child: _MiniModeButton(label: 'AI+자료 혼합', icon: Icons.auto_awesome_rounded, onTap: onMixed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniModeButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1899D6)),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  final Map<String, dynamic> session;

  const _RecentSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final subject = (session['subject'] ?? session['topic'] ?? '이름 없는 학습').toString();
    final progress = _toDouble(session['progress']).clamp(0.0, 1.0);
    final mode = questionGenerationModeFromApiValue(session['generation_mode']?.toString());
    final level = learningLevelFromApiValue((session['learning_level'] ?? session['difficulty'])?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 8),
          Text('${mode.label} · ${level.label}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0xFFE5E5E5), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
