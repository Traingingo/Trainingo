import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/question_generation_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class ProgressingLearningScreen extends StatefulWidget {
  const ProgressingLearningScreen({super.key});

  @override
  State<ProgressingLearningScreen> createState() => _ProgressingLearningScreenState();
}

class _ProgressingLearningScreenState extends State<ProgressingLearningScreen> {
  bool _requestedInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LearningProvider>().fetchUserSessions(user.id);
      }
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '아직 학습 기록 없음';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();
    final sessions = learningProvider.userSessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('진행 중인 학습', style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3C3C3C)),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                context.read<LearningProvider>().fetchUserSessions(user.id);
              }
            },
          ),
        ],
      ),
      body: sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 76, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('진행 중인 학습이 없습니다.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                    const SizedBox(height: 8),
                    const Text('홈에서 주제를 입력하거나 자료를 업로드해 새 학습을 만들어 보세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    DuoButton(text: '홈으로 이동', onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final subject = session['subject']?.toString() ?? '이름 없는 학습';
                final progress = _toDouble(session['progress']).clamp(0.0, 1.0).toDouble();
                final generationMode = QuestionGenerationModeX.fromApiValue(session['generation_mode']);
                final difficulty = LearningLevelX.fromApiValue(session['difficulty']);

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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(label: generationMode.label, color: const Color(0xFF1899D6), icon: Icons.auto_awesome),
                          _MetaChip(label: difficulty.label, color: const Color(0xFF58CC02), icon: Icons.signal_cellular_alt),
                          _MetaChip(label: '최근 ${_formatDate(session['last_studied_at'])}', color: Colors.deepPurple, icon: Icons.schedule),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                backgroundColor: const Color(0xFFE5E5E5),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DuoButton(
                        text: '이어서 학습하기',
                        color: const Color(0xFF1899D6),
                        shadowColor: const Color(0xFF147EA9),
                        icon: Icons.play_arrow,
                        onPressed: () {
                          context.read<LearningProvider>().loadSession(session);
                          Navigator.pushNamed(context, AppRoutes.lessons);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _MetaChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
