import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/learning_provider.dart';
import '../../providers/question_provider.dart';
import '../../widgets/question/question_card.dart';
import '../../widgets/common/duo_button.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  bool _isChecked = false;
  bool _isAnswerCorrect = false;

  @override
  Widget build(BuildContext context) {
    final questionProvider = context.watch<QuestionProvider>();
    final lessonId = ModalRoute.of(context)?.settings.arguments as int? ?? 1;
    final learningProvider = context.watch<LearningProvider>();
    final lesson = learningProvider.lessons.firstWhere((l) => l.id == lessonId, orElse: () => learningProvider.lessons.first);

    // 1. AI 문제 생성 로딩 중 화면
    if (questionProvider.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  '${lesson.title}\nAI 퀴즈 생성 중...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3C3C3C),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '최적의 맞춤 학습 문제를 조합하고 있습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = questionProvider.currentQuestion;

    // 2. 문제 자체가 없는 경우 예외 처리
    if (question == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('퀴즈 오류'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  '문제를 불러오지 못했습니다.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DuoButton(
                  text: '뒤로 돌아가기',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 퀴즈 진행률 계산 (0.0 ~ 1.0)
    final progress = questionProvider.questions.isEmpty
        ? 0.0
        : (questionProvider.currentIndex) / questionProvider.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // 상단 X 버튼
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF3C3C3C)),
              onPressed: () {
                // 정말 중단할 것인지 확인 다이얼로그
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('학습 중단', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('지금 종료하면 학습 진행 상황이 저장되지 않습니다. 정말 나갈까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('계속 공부하기'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // 다이얼로그 닫기
                          Navigator.pop(context); // 퀴즈 화면 닫기
                        },
                        child: const Text('종료하기', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            // 듀오링고 스타일 상단 프로그레스 바
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE5E5E5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF58CC02),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 하트/생명 개수 표시 (데코레이션)
            Row(
              children: const [
                Icon(Icons.favorite, color: Colors.red, size: 24),
                SizedBox(width: 4),
                Text(
                  '3',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF3C3C3C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: QuestionCard(
              question: question,
              selectedAnswer: questionProvider.selectedAnswer,
              onSelected: _isChecked
                  ? (_) {} // 이미 정답 검증이 끝난 후에는 터치 불가
                  : (val) => questionProvider.selectAnswer(val),
            ),
          ),

          // 듀오링고 스타일의 하단 정답 체크/피드백 바
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: !_isChecked
                  ? Colors.white
                  : _isAnswerCorrect
                      ? const Color(0xFFD7FFB7) // 정답 피드백 그린
                      : const Color(0xFFFFDFE0), // 오답 피드백 레드
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
                  // 1. 채점 완료 피드백 텍스트 영역
                  if (_isChecked) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isAnswerCorrect ? const Color(0xFF58CC02) : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isAnswerCorrect ? Icons.check : Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isAnswerCorrect ? '정답입니다! 참 잘했어요.' : '아쉬워요, 오답입니다.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _isAnswerCorrect
                                ? const Color(0xFF46A302)
                                : Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 정답이 아닐 때 올바른 정답 안내
                    if (!_isAnswerCorrect) ...[
                      Text(
                        '올바른 정답: ${question.answer}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    // AI의 설명 제공
                    Text(
                      question.explanation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isAnswerCorrect
                            ? const Color(0xFF3F8A00)
                            : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 2. 액션 버튼
                  if (!_isChecked)
                    DuoButton(
                      text: '정답 확인',
                      color: const Color(0xFF58CC02),
                      shadowColor: const Color(0xFF46A302),
                      onPressed: questionProvider.selectedAnswer == null
                          ? null
                          : () {
                              setState(() {
                                _isAnswerCorrect = questionProvider.checkAnswer();
                                _isChecked = true;
                              });
                            },
                    )
                  else
                    DuoButton(
                      text: questionProvider.isLastQuestion ? '학습 완료' : '다음 문제',
                      color: _isAnswerCorrect
                          ? const Color(0xFF58CC02)
                          : const Color(0xFFFF5252),
                      shadowColor: _isAnswerCorrect
                          ? const Color(0xFF46A302)
                          : const Color(0xFFD32F2F),
                      onPressed: () {
                        if (questionProvider.isLastQuestion) {
                          // 코스 완료 처리
                          context
                              .read<LearningProvider>()
                              .completeLesson(lessonId);
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            _isChecked = false;
                            _isAnswerCorrect = false;
                          });
                          questionProvider.nextQuestion();
                        }
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
}