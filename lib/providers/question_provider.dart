import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/question_model.dart';
import '../services/question_service.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<QuestionModel> questions = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = false;
  String? selectedAnswer;

  // 하트(생명) 상태
  int hearts = 3;
  final int maxHearts = 3;

  QuestionModel? get currentQuestion {
    if (questions.isEmpty) return null;
    return questions[currentIndex];
  }

  bool get isLastQuestion {
    return currentIndex == questions.length - 1;
  }

  // 비동기 사운드 재생 헬퍼
  Future<void> _playAudio(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      print("🔊 오디오 재생 에러: $e");
    }
  }

  void playCorrectSound() {
    _playAudio('https://assets.mixkit.co/active_storage/sfx/2869/2869-84.wav');
  }

  void playIncorrectSound() {
    _playAudio('https://assets.mixkit.co/active_storage/sfx/2873/2873-84.wav');
  }

  void playVictorySound() {
    _playAudio('https://assets.mixkit.co/active_storage/sfx/2019/2019-84.wav');
  }

  Future<void> generateQuestions({
    required String subject,
    required String difficulty,
    required String type,
    int sessionId = 0,
    String levelTitle = "",
    String levelDescription = "",
  }) async {
    isLoading = true;
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    hearts = maxHearts; // 하트 충전
    notifyListeners();

    questions = await _questionService.generateQuestions(
      subject: subject,
      difficulty: difficulty,
      type: type,
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

    final isCorrect = selectedAnswer == question.answer;
    if (isCorrect) {
      score++;
      playCorrectSound();
    } else {
      hearts--; // 틀리면 하트 깎임!
      playIncorrectSound();

      // 백엔드 DB 오답노트에 비동기로 저장
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

  void nextQuestion() {
    if (!isLastQuestion) {
      currentIndex++;
      selectedAnswer = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}