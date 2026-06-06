import 'package:flutter/material.dart';

import '../models/learning_mode.dart';
import '../models/lesson_model.dart';
import '../models/question_generation_config.dart';
import '../services/question_policy_service.dart';
import '../services/question_service.dart';

class LearningProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<LessonModel> lessons = [];
  String currentSubject = "";
  int currentSessionId = 0;
  bool isLoading = false;
  LearningMode selectedLearningMode = LearningMode.recommended;

  List<Map<String, dynamic>> userSessions = [];

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completed = lessons.where((lesson) => lesson.isCompleted).length;
    return completed / lessons.length;
  }

  void setSelectedLearningMode(LearningMode mode) {
    selectedLearningMode = mode;
    notifyListeners();
  }

  QuestionGenerationConfig buildQuestionConfigForLevel(int level, {int count = 10}) {
    final subjectType = SubjectClassifier.classify(subject: currentSubject);
    final allowedTypes = SubjectQuestionPolicy.allowedTypes(
      subjectType,
      subjectName: currentSubject,
    );
    final weights = LearningModePlanner.buildWeights(
      mode: selectedLearningMode,
      level: level,
      subjectType: subjectType,
      subjectName: currentSubject,
    );

    return QuestionGenerationConfig(
      mode: selectedLearningMode,
      subjectType: subjectType,
      allowedTypes: allowedTypes,
      weights: weights,
      level: level,
      count: count,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<LessonModel> _parseLessons(dynamic rawLessons) {
    if (rawLessons is List) {
      return rawLessons.where((item) => item is LessonModel || item is Map).map((item) {
        if (item is LessonModel) {
          return item;
        }

        final map = Map<String, dynamic>.from(item as Map);
        return LessonModel(
          id: _toInt(map['id']),
          title: map['title']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
          level: _toInt(map['level']) == 0 ? 1 : _toInt(map['level']),
          isLocked: map['isLocked'] ?? true,
          isCompleted: map['isCompleted'] ?? false,
        );
      }).toList();
    }

    return [];
  }

  Future<void> generateCurriculum(String subject, int userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final result = await _questionService.generateCurriculum(
        subject: subject,
        userId: userId,
      );

      currentSessionId = _toInt(result["sessionId"]);
      currentSubject = result["subject"] ?? subject;
      lessons = _parseLessons(result["lessons"]);
      await fetchUserSessions(userId);
    } catch (e) {
      print("커리큘럼 생성 실패: $e");
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserSessions(int userId) async {
    final list = await _questionService.fetchUserSessions(userId);
    userSessions = list;
    notifyListeners();
  }

  void loadSession(Map<String, dynamic> session) {
    currentSessionId = _toInt(session["id"]);
    currentSubject = session["subject"]?.toString() ?? "";
    selectedLearningMode = LearningMode.recommended;
    lessons = _parseLessons(session["lessons"]);
    notifyListeners();
  }

  void loadSessionFromUploadResponse(Map<String, dynamic> response) {
    currentSessionId = _toInt(response["session_id"]);
    currentSubject = response["subject"]?.toString() ?? "";
    selectedLearningMode = LearningMode.recommended;
    lessons = _parseLessons(response["curriculum"]);

    final double uploadedProgress = _toDouble(response["progress"]);
    var updated = false;
    userSessions = userSessions.map((session) {
      if (_toInt(session["id"]) == currentSessionId) {
        updated = true;
        return {
          ...session,
          "subject": currentSubject,
          "progress": uploadedProgress,
          "lessons": lessons,
        };
      }
      return session;
    }).toList();

    if (!updated && currentSessionId > 0) {
      userSessions = [
        {
          "id": currentSessionId,
          "subject": currentSubject,
          "progress": uploadedProgress,
          "lessons": lessons,
        },
        ...userSessions,
      ];
    }

    notifyListeners();
  }

  Future<void> completeLesson(int lessonId) async {
    LessonModel? completedLesson;
    for (final lesson in lessons) {
      if (lesson.id == lessonId) {
        completedLesson = lesson;
        break;
      }
    }
    final nextLevel = completedLesson == null ? null : completedLesson.level + 1;

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

      if (nextLevel != null && lesson.level == nextLevel) {
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

    if (currentSessionId > 0) {
      await _questionService.completeLesson(
        sessionId: currentSessionId,
        lessonId: lessonId,
      );
    }
  }
}
