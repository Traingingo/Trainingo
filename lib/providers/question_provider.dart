import 'package:flutter/material.dart';

import '../models/question_generation_config.dart';
import '../models/question_model.dart';
import '../models/question_type.dart';
import '../services/answer_grading_service.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();
  final AnswerGradingService _answerGradingService = AnswerGradingService();

  List<QuestionModel> questions = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = false;
  String? selectedAnswer;
  AnswerGradeResult? lastGradeResult;

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
    String levelTitle = '',
    String levelDescription = '',
  }) async {
    isLoading = true;
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    lastGradeResult = null;
    hearts = maxHearts;
    questions = [];
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
    required int sessionId,
    required String subject,
  }) {
    final question = currentQuestion;
    if (question == null || selectedAnswer == null) return false;

    final gradeResult = _answerGradingService.grade(
      question: question,
      userAnswer: selectedAnswer!,
    );
    final isCorrect = gradeResult.isCorrect;
    lastGradeResult = gradeResult;

    if (isCorrect) {
      score++;
    } else {
      hearts--;
    }

    _questionService.saveAnswerRecord(
      userId: userId,
      sessionId: sessionId,
      questionId: question.id,
      userAnswer: selectedAnswer!,
      isCorrect: isCorrect,
    );

    if (!isCorrect) {
      _questionService.saveIncorrectAnswer(
        userId: userId,
        sessionId: sessionId,
        questionId: question.id,
        subject: subject,
        question: question.question,
        options: question.options,
        answer: question.displayAnswer,
        modelAnswer: question.displayAnswer,
        explanation: question.explanation,
        userAnswer: selectedAnswer!,
        questionType: question.type.apiValue,
        difficulty: question.difficulty,
      );
    }

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
