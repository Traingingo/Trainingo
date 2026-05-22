import 'package:flutter/material.dart';

import '../models/lesson_model.dart';
import '../services/question_service.dart';

class LearningProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<LessonModel> lessons = [];
  String currentSubject = "";
  bool isLoading = false;

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completed = lessons.where((lesson) => lesson.isCompleted).length;
    return completed / lessons.length;
  }

  Future<void> generateCurriculum(String subject) async {
    isLoading = true;
    notifyListeners();

    try {
      final newLessons = await _questionService.generateCurriculum(subject: subject);
      lessons = newLessons;
      currentSubject = subject;
    } catch (e) {
      print("❌ 커리큘럼 생성 실패: $e");
      // 예외 발생 시 더미 데이터를 설정하지 않고 그대로 에러를 상위로 던지거나 알립니다.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void completeLesson(int lessonId) {
    lessons = lessons.map((lesson) {
      if (lesson.id == lessonId) {
        return LessonModel(
          id: lesson.id,
          title: lesson.title,
          description: lesson.description,
          level: lesson.level,
          isLocked: false,
          isCompleted: true,
        );
      }

      // 다음 레벨 해제
      if (lesson.id == lessonId + 1) {
        return LessonModel(
          id: lesson.id,
          title: lesson.title,
          description: lesson.description,
          level: lesson.level,
          isLocked: false,
          isCompleted: lesson.isCompleted,
        );
      }

      return lesson;
    }).toList();

    notifyListeners();
  }
}