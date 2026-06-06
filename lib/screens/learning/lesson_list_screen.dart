import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/lesson_model.dart';
import '../../models/question_generation_mode.dart';
import '../../providers/learning_provider.dart';
import '../../providers/question_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  void _startLesson(BuildContext context, LessonModel lesson, String subject) {
    final learningProvider = context.read<LearningProvider>();
    final config = learningProvider.buildQuestionConfigForLevel(lesson.level);

    context.read<QuestionProvider>().generateQuestions(
          subject: subject,
          difficulty: learningProvider.selectedLearningLevel.label,
          config: config,
          sessionId: learningProvider.currentSessionId,
          levelTitle: lesson.title,
          levelDescription: lesson.description,
        );

    Navigator.pushNamed(context, AppRoutes.questions, arguments: lesson.id);
  }

  void _showLessonDetailBottomSheet(BuildContext context, LessonModel lesson, String subject) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lesson.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3C3C3C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lesson.description,
                style: const TextStyle(fontSize: 15, color: Color(0xFF4B4B4B), height: 1.4),
              ),
              const SizedBox(height: 16),
              _SetupSummary(provider: context.read<LearningProvider>()),
              const SizedBox(height: 24),
              DuoButton(
                text: lesson.isCompleted ? '다시 학습하기' : '학습 시작하기',
                color: const Color(0xFF58CC02),
                shadowColor: const Color(0xFF46A302),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  _startLesson(context, lesson, subject);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  double _nodeAlignment(int index) {
    final pos = index % 4;
    if (pos == 1) return -0.5;
    if (pos == 3) return 0.5;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();
    final lessons = learningProvider.lessons;
    final subject = learningProvider.currentSubject;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          subject.isNotEmpty ? '$subject 학습 경로' : '단계별 학습',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C), fontSize: 18),
        ),
      ),
      body: lessons.isEmpty
          ? Center(
              child: DuoButton(
                text: '홈으로 이동',
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _SetupSummary(provider: learningProvider),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    itemCount: lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = lessons[index];
                      final alignX = _nodeAlignment(index);
                      final isLast = index == lessons.length - 1;

                      return Column(
                        children: [
                          Align(
                            alignment: Alignment(alignX, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: lesson.isLocked
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('이전 레벨을 완료해야 잠금이 해제됩니다!')),
                                          );
                                        }
                                      : () => _showLessonDetailBottomSheet(context, lesson, subject),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 100),
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: lesson.isLocked
                                          ? const Color(0xFFE5E5E5)
                                          : lesson.isCompleted
                                              ? const Color(0xFFFFC800)
                                              : const Color(0xFF58CC02),
                                      boxShadow: [
                                        BoxShadow(
                                          color: lesson.isLocked
                                              ? const Color(0xFFB8B8B8)
                                              : lesson.isCompleted
                                                  ? const Color(0xFFC79C00)
                                                  : const Color(0xFF46A302),
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        lesson.isLocked
                                            ? Icons.lock
                                            : lesson.isCompleted
                                                ? Icons.star
                                                : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  lesson.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: lesson.isLocked ? Colors.grey : const Color(0xFF3C3C3C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment(alignX, 0),
                              child: Container(
                                width: 8,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E5E5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SetupSummary extends StatelessWidget {
  final LearningProvider provider;

  const _SetupSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: _MetaText(label: '생성 방식', value: provider.selectedGenerationMode.label, color: const Color(0xFF1899D6))),
          Container(width: 1, height: 32, color: const Color(0xFFE5E5E5)),
          Expanded(child: _MetaText(label: '학습 수준', value: provider.selectedLearningLevel.label, color: const Color(0xFF58CC02))),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetaText({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
