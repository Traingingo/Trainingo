import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/question_generation_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/question_service.dart';
import '../../widgets/common/duo_button.dart';

class ProgressingLearningScreen extends StatefulWidget {
  const ProgressingLearningScreen({super.key});

  @override
  State<ProgressingLearningScreen> createState() => _ProgressingLearningScreenState();
}

class _ProgressingLearningScreenState extends State<ProgressingLearningScreen> {
  final QuestionService _questionService = QuestionService();
  bool _requestedInitialLoad = false;
  bool _isDeleting = false;

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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '최근 학습 기록 없음';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteSession(Map<String, dynamic> session) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final sessionId = _toInt(session['id']);
    if (sessionId <= 0) return;

    final subject = session['subject']?.toString() ?? '이 학습';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('학습 삭제'),
          content: Text(
            '"$subject" 학습을 삭제할까요?\n\n학습 경로, 문제, 풀이 기록, 관련 오답노트가 함께 정리됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final success = await _questionService.deleteStudySession(
      userId: user.id,
      sessionId: sessionId,
    );

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (success) {
      await context.read<LearningProvider>().fetchUserSessions(user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학습 목록에서 삭제되었습니다.'),
          backgroundColor: Color(0xFF58CC02),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학습 삭제에 실패했습니다.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
        title: const Text(
          '진행 중인 학습',
          style: TextStyle(
            color: Color(0xFF3C3C3C),
            fontWeight: FontWeight.w900,
          ),
        ),
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
      body: Stack(
        children: [
          if (sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: Color(0xFF58CC02),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '진행 중인 학습이 없습니다.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3C3C3C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '홈에서 새로운 주제를 입력하고\n학습을 시작해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    DuoButton(
                      text: '홈으로 이동',
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];

                final sessionId = _toInt(session['id']);
                final subject = session['subject']?.toString() ?? '이름 없는 학습';
                final progress = _toDouble(session['progress']).clamp(0.0, 1.0);

                final mode = QuestionGenerationModeX.fromApiValue(
                  session['generation_mode']?.toString(),
                );

                final level = LearningLevelX.fromApiValue(
                  session['difficulty']?.toString(),
                );

                final lastStudiedAt = _formatDate(session['last_studied_at']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5E5E5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF8E1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.play_lesson,
                              color: Color(0xFF58CC02),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF3C3C3C),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '최근 학습: $lastStudiedAt',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteSession(session),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: mode.label,
                            backgroundColor: const Color(0xFFE1F5FE),
                            textColor: const Color(0xFF0288D1),
                          ),
                          _InfoChip(
                            label: level.label,
                            backgroundColor: const Color(0xFFFFF3E0),
                            textColor: const Color(0xFFEF6C00),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFE5E5E5),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF58CC02),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '진행률 ${(progress * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF58CC02),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DuoButton(
                        text: '이어서 학습하기',
                        color: const Color(0xFF1899D6),
                        shadowColor: const Color(0xFF147EA9),
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
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }
}