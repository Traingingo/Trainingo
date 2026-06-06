import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_setup_options.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class OngoingLearningScreen extends StatefulWidget {
  const OngoingLearningScreen({super.key});

  @override
  State<OngoingLearningScreen> createState() => _OngoingLearningScreenState();
}

class _OngoingLearningScreenState extends State<OngoingLearningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      await context.read<LearningProvider>().fetchUserSessions(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningProvider>();
    final sessions = provider.userSessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('진행 중인 학습', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3C3C3C)))],
      ),
      body: sessions.isEmpty
          ? const _EmptyOngoingLearning()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _SessionCard(
                    session: session,
                    onContinue: () {
                      context.read<LearningProvider>().loadSession(session);
                      Navigator.pushNamed(context, AppRoutes.lessons);
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyOngoingLearning extends StatelessWidget {
  const _EmptyOngoingLearning();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.play_circle_outline_rounded, size: 76, color: Colors.grey),
            SizedBox(height: 16),
            Text('진행 중인 학습이 없습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
            SizedBox(height: 8),
            Text('홈에서 새로운 주제 학습을 만들어 보세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onContinue;

  const _SessionCard({required this.session, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final subject = (session['subject'] ?? session['topic'] ?? '이름 없는 학습').toString();
    final progress = _toDouble(session['progress']).clamp(0.0, 1.0);
    final generationMode = QuestionGenerationModeX.fromApiValue(session['generation_mode']?.toString());
    final level = LearningLevelX.fromApiValue((session['learning_level'] ?? session['difficulty'])?.toString());
    final lastStudiedAt = (session['last_studied_at'] ?? session['updated_at'] ?? session['created_at'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.auto_awesome_rounded, label: generationMode.label),
              _InfoChip(icon: Icons.signal_cellular_alt_rounded, label: level.label),
              if (lastStudiedAt.isNotEmpty) _InfoChip(icon: Icons.history_rounded, label: _formatDate(lastStudiedAt)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFE5E5E5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
            ),
          ),
          const SizedBox(height: 8),
          Text('진행률 ${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          DuoButton(
            text: '이어서 학습하기',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF1899D6),
            shadowColor: const Color(0xFF147EA9),
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEAF8E1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF46A302)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF46A302))),
        ],
      ),
    );
  }
}
