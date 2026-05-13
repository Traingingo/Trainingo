import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/learning_provider.dart';
import '../../providers/question_provider.dart';
import '../../widgets/question/question_card.dart';

class QuestionScreen extends StatelessWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final questionProvider = context.watch<QuestionProvider>();
    final lessonId = ModalRoute.of(context)?.settings.arguments as int? ?? 1;

    if (questionProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = questionProvider.currentQuestion;

    if (question == null) {
      return const Scaffold(
        body: Center(child: Text('문제가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '문제 ${questionProvider.currentIndex + 1}/${questionProvider.questions.length}',
        ),
      ),
      body: Column(
        children: [
          QuestionCard(
            question: question,
            selectedAnswer: questionProvider.selectedAnswer,
            onSelected: questionProvider.selectAnswer,
          ),
          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: questionProvider.selectedAnswer == null
                    ? null
                    : () {
                  final isCorrect = questionProvider.checkAnswer();

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(isCorrect ? '정답입니다!' : '오답입니다.'),
                      content: Text(question.explanation),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);

                            if (questionProvider.isLastQuestion) {
                              context
                                  .read<LearningProvider>()
                                  .completeLesson(lessonId);

                              Navigator.pop(context);
                            } else {
                              questionProvider.nextQuestion();
                            }
                          },
                          child: Text(
                            questionProvider.isLastQuestion
                                ? '학습 완료'
                                : '다음 문제',
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('정답 확인'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}