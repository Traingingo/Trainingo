import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/question_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../widgets/common/duo_button.dart';
import '../../widgets/question/question_card_dispatcher.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  bool _isChecked = false;
  bool _isAnswerCorrect = false;

  void _goBackSafely(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionProvider = context.watch<QuestionProvider>();
    final learningProvider = context.watch<LearningProvider>();
    final lessonId = ModalRoute.of(context)?.settings.arguments as int? ?? 0;

    if (learningProvider.lessons.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('학습 정보 없음'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('현재 선택된 학습 로드맵이 없습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  '새로고침 또는 직접 URL 접근으로 학습 상태가 초기화되었을 수 있습니다.\n홈에서 로드맵을 다시 선택해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                DuoButton(text: '홈으로 이동', onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home)),
              ],
            ),
          ),
        ),
      );
    }

    final lesson = learningProvider.lessons.firstWhere(
      (lesson) => lesson.id == lessonId,
      orElse: () => learningProvider.lessons.first,
    );

    if (questionProvider.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '${lesson.title}\nAI 맞춤 문제 생성 중...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                ),
                const SizedBox(height: 12),
                const Text('과목 성격과 레벨에 맞춰 여러 문제 유형을 조합하고 있습니다.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    final question = questionProvider.currentQuestion;
    if (question == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('퀴즈 오류'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _goBackSafely(context)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('문제를 불러오지 못했습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DuoButton(text: '뒤로 돌아가기', onPressed: () => _goBackSafely(context)),
              ],
            ),
          ),
        ),
      );
    }

    final progress = questionProvider.questions.isEmpty ? 0.0 : (questionProvider.currentIndex + 1) / questionProvider.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF3C3C3C)),
              onPressed: () => _showExitDialog(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE5E5E5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${questionProvider.currentIndex + 1}/${questionProvider.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF3C3C3C)),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 24),
                const SizedBox(width: 4),
                Text(
                  '${questionProvider.hearts}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF3C3C3C)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: QuestionCardDispatcher(
              question: question,
              selectedAnswer: questionProvider.selectedAnswer,
              isLocked: _isChecked,
              onChanged: (val) {
                SoundService.instance.play(SoundEffect.click);
                questionProvider.selectAnswer(val);
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: !_isChecked
                  ? Colors.white
                  : _isAnswerCorrect
                      ? const Color(0xFFD7FFB7)
                      : const Color(0xFFFFDFE0),
              border: Border(
                top: BorderSide(
                  color: !_isChecked ? const Color(0xFFE5E5E5) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isChecked) ...[
                    _FeedbackSummary(
                      isCorrect: _isAnswerCorrect,
                      answer: question.answer,
                      explanation: question.explanation,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (!_isChecked)
                    DuoButton(
                      text: '정답 확인',
                      color: const Color(0xFF58CC02),
                      shadowColor: const Color(0xFF46A302),
                      onPressed: questionProvider.selectedAnswer == null
                          ? null
                          : () {
                              final user = context.read<AuthProvider>().user;
                              final subject = learningProvider.currentSubject;
                              final isCorrect = questionProvider.checkAnswer(
                                userId: user?.id ?? 1,
                                subject: subject,
                              );
                              SoundService.instance.play(isCorrect ? SoundEffect.correct : SoundEffect.wrong);
                              setState(() {
                                _isAnswerCorrect = isCorrect;
                                _isChecked = true;
                              });
                              if (questionProvider.hearts <= 0) {
                                _showHeartEmptyDialog(context);
                              }
                            },
                    )
                  else
                    DuoButton(
                      text: questionProvider.isLastQuestion ? '학습 완료' : '다음 문제',
                      color: _isAnswerCorrect ? const Color(0xFF58CC02) : const Color(0xFFFF5252),
                      shadowColor: _isAnswerCorrect ? const Color(0xFF46A302) : const Color(0xFFFF5252),
                      onPressed: () {
                        if (questionProvider.isLastQuestion) {
                          SoundService.instance.play(SoundEffect.complete);
                          context.read<LearningProvider>().completeLesson(lesson.id);
                          _goBackSafely(context);
                          return;
                        }
                        if (questionProvider.hearts <= 0) return;
                        setState(() {
                          _isChecked = false;
                          _isAnswerCorrect = false;
                        });
                        questionProvider.nextQuestion();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('학습 중단', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('지금 종료하면 학습 진행 상황이 저장되지 않습니다. 정말 나갈까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('계속 공부하기')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goBackSafely(context);
            },
            child: const Text('종료하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showHeartEmptyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('하트 소진!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('하트를 모두 소진했습니다. 단원 목록으로 돌아가서 다시 시도해 주세요!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goBackSafely(context);
            },
            child: const Text('확인', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSummary extends StatelessWidget {
  final bool isCorrect;
  final String answer;
  final String explanation;

  const _FeedbackSummary({
    required this.isCorrect,
    required this.answer,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = isCorrect ? const Color(0xFF46A302) : Colors.red.shade900;
    final Color detailColor = isCorrect ? const Color(0xFF3F8A00) : Colors.red.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: isCorrect ? const Color(0xFF58CC02) : Colors.redAccent, shape: BoxShape.circle),
              child: Icon(isCorrect ? Icons.check : Icons.close, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCorrect ? '정답입니다! 참 잘했어요.' : '아쉬워요, 오답입니다.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor),
              ),
            ),
          ],
        ),
        if (!isCorrect) ...[
          const SizedBox(height: 12),
          Text('올바른 정답: $answer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
        ],
        const SizedBox(height: 8),
        Text(explanation, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: detailColor)),
      ],
    );
  }
}
