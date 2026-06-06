import 'package:flutter/material.dart';

import '../models/question_generation_config.dart';
import '../models/question_model.dart';
import '../services/answer_grading_service.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();
  final AnswerGradingService _answerGradingService = AnswerGradingService();

  List<QuestionModel> questions = [];
  int currentIndex = 0;
  int score = 0;
  int activeSessionId = 0;
  bool isLoading = false;
  String? selectedAnswer;
  AnswerGradeResult? lastGradeResult;

  int hearts = 3;
  final int maxHearts = 3;

  QuestionModel? get currentQuestion {
    if (questions.isEmpty) return null;
    return questions[currentIndex];
  }

  bool get isLastQuestion => currentIndex == questions.length - 1;

  Future<void> generateQuestions({
    required String subject,
    required String difficulty,
    required QuestionGenerationConfig config,
    int sessionId = 0,
    String levelTitle = '',
    String levelDescription = '',
  }) async {
    isLoading = true;
    currentIndex = 0;
    score = 0;
    activeSessionId = sessionId;
    selectedAnswer = null;
    lastGradeResult = null;
    hearts = maxHearts;
    notifyListeners();

    try {
      questions = await _questionService.generateQuestions(
        subject: subject,
        difficulty: difficulty,
        config: config,
        sessionId: sessionId,
        levelTitle: levelTitle,
        levelDescription: levelDescription,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectAnswer(String answer) {
    selectedAnswer = answer;
    notifyListeners();
  }

  bool checkAnswer({
    required int userId,
    required String subject,
    int sessionId = 0,
  }) {
    final question = currentQuestion;
    final answer = selectedAnswer;
    if (question == null || answer == null) return false;

    final gradeResult = _answerGradingService.grade(question: question, userAnswer: answer);
    final isCorrect = gradeResult.isCorrect;
    lastGradeResult = gradeResult;

    if (isCorrect) {
      score++;
    } else {
      hearts--;
    }

    _questionService.submitAnswer(
      userId: userId,
      sessionId: sessionId > 0 ? sessionId : activeSessionId,
      subject: subject,
      question: question,
      userAnswer: answer,
      isCorrect: isCorrect,
    );

    notifyListeners();
    return isCorrect;
  }

  void nextQuestion() {
    if (!isLastQuestion) {
      currentIndex++;
      selectedAnswer = null;
      lastGradeResult = null;
      notifyListeners();
    }
  }
}
