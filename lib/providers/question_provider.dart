import 'package:flutter/material.dart';

import '../models/question_model.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<QuestionModel> questions = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = false;
  String? selectedAnswer;

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
    required String type,
    String levelTitle = "",
    String levelDescription = "",
  }) async {
    isLoading = true;
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    notifyListeners();

    questions = await _questionService.generateQuestions(
      subject: subject,
      difficulty: difficulty,
      type: type,
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

  bool checkAnswer() {
    final question = currentQuestion;
    if (question == null || selectedAnswer == null) return false;

    final isCorrect = selectedAnswer == question.answer;
    if (isCorrect) score++;

    notifyListeners();
    return isCorrect;
  }

  void nextQuestion() {
    if (!isLastQuestion) {
      currentIndex++;
      selectedAnswer = null;
      notifyListeners();
    }
  }
}