import 'package:flutter/material.dart';

import '../models/lesson_model.dart';
import '../services/question_service.dart';

class LearningProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<LessonModel> lessons = [];
  String currentSubject = "";
  int currentSessionId = 0;
  bool isLoading = false;
  
  // 사용자의 전체 학습 세션 목록 (이어서 학습하기용)
  List<Map<String, dynamic>> userSessions = [];

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completed = lessons.where((lesson) => lesson.isCompleted).length;
    return completed / lessons.length;
  }

  // 커리큘럼 생성 및 신규 세션 등록
  Future<void> generateCurriculum(String subject, int userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final result = await _questionService.generateCurriculum(
        subject: subject,
        userId: userId,
      );
      
      currentSessionId = result["sessionId"] ?? 0;
      currentSubject = result["subject"] ?? subject;
      lessons = result["lessons"] as List<LessonModel>;
      
      // 세션 목록 갱신
      await fetchUserSessions(userId);
    } catch (e) {
      print("❌ 커리큘럼 생성 실패: $e");
      rethrow; // 에러를 화면 단으로 전파하여 SnackBar 등으로 표시하도록 함
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 사용자 학습 세션 목록 불러오기
  Future<void> fetchUserSessions(int userId) async {
    final list = await _questionService.fetchUserSessions(userId);
    userSessions = list;
    notifyListeners();
  }

  // 기존 세션 이어서 학습하기 활성화
  void loadSession(Map<String, dynamic> session) {
    currentSessionId = session["id"] ?? 0;
    currentSubject = session["subject"] ?? "";
    lessons = session["lessons"] as List<LessonModel>;
    notifyListeners();
  }

  // 단원(레벨) 완료 처리 및 DB 반영
  Future<void> completeLesson(int lessonId) async {
    // 1. 메모리 상의 완료 처리 및 다음 단계 해금
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

    // 2. 백엔드 DB 업데이트 요청
    if (currentSessionId > 0) {
      await _questionService.completeLesson(
        sessionId: currentSessionId,
        lessonId: lessonId,
      );
    }
  }
}