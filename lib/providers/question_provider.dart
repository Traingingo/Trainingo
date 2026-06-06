import 'package:flutter/material.dart';

import '../models/question_generation_config.dart';
import '../models/question_model.dart';
import '../models/question_type.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<QuestionModel> questions = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = false;
  String? selectedAnswer;

  int hearts = 3;
  final int maxHearts = 3;

  QuestionModel? get currentQuestion {
    if (questions.isEmpty) return null;
    return questions[currentIndex];
  }

  bool get isLastQuestion {
    return currentIndex == questions.length - 1;
  }

  Future<void> generateQuestions({
    required String subject,
    required String difficulty,
    required QuestionGenerationConfig config,
    int sessionId = 0,
    String levelTitle = "",
    String levelDescription = "",
  }) async {
    isLoading = true;
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    hearts = maxHearts;
    notifyListeners();

    questions = await _questionService.generateQuestions(
      subject: subject,
      difficulty: difficulty,
      config: config,
      sessionId: sessionId,
      levelTitle: levelTitle,
      levelDescription: levelDescription,
    );

    isLoading = false;
    notifyListeners();
  }

  void selectAnswer(String answer) {
    selectedAnswer = answer;
    notifyListeners();
  }

  bool checkAnswer({required int userId, required String subject}) {
    final question = currentQuestion;
    if (question == null || selectedAnswer == null) return false;

    final userAnswer = selectedAnswer!.trim();
    final correctAnswer = question.answer.trim();
    final isCorrect = _isCorrectAnswer(question, userAnswer, correctAnswer);

    if (isCorrect) {
      score++;
    } else {
      hearts--;
      _questionService.saveIncorrectAnswer(
        userId: userId,
        subject: subject,
        question: question.question,
        options: question.options,
        answer: question.answer,
        explanation: question.explanation,
        userAnswer: selectedAnswer!,
      );
    }

    notifyListeners();
    return isCorrect;
  }

  bool _isCorrectAnswer(QuestionModel question, String userAnswer, String correctAnswer) {
    final normalizedUser = userAnswer.toLowerCase().replaceAll(' ', '');
    final normalizedCorrect = correctAnswer.toLowerCase().replaceAll(' ', '');

    switch (question.type) {
      case QuestionType.multipleChoice:
      case QuestionType.shortAnswer:
      case QuestionType.calculation:
      case QuestionType.codeReading:
        return normalizedUser == normalizedCorrect;
      case QuestionType.descriptive:
      case QuestionType.coding:
      case QuestionType.sqlWriting:
      case QuestionType.commandWriting:
        return normalizedUser == normalizedCorrect;
    }
  }

  void nextQuestion() {
    if (!isLastQuestion) {
      currentIndex++;
      selectedAnswer = null;
      notifyListeners();
    }
  }
}
