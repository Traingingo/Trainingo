import 'package:flutter/material.dart';

import '../models/learning_level.dart';
import '../models/learning_mode.dart';
import '../models/lesson_model.dart';
import '../models/question_generation_config.dart';
import '../models/question_generation_mode.dart';
import '../services/question_policy_service.dart';
import '../services/question_service.dart';

class LearningProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<LessonModel> lessons = [];
  String currentSubject = '';
  int currentSessionId = 0;
  bool isLoading = false;
  LearningMode selectedLearningMode = LearningMode.recommended;
  LearningLevel selectedLearningLevel = LearningLevel.beginner;
  QuestionGenerationMode selectedGenerationMode = QuestionGenerationMode.aiOnly;

  List<Map<String, dynamic>> userSessions = [];

  double get progress {
    if (lessons.isEmpty) return 0.0;
    final completed = lessons.where((lesson) => lesson.isCompleted).length;
    return completed / lessons.length;
  }

  String get selectedDifficultyLabel => selectedLearningLevel.label;

  void setSelectedLearningMode(LearningMode mode) {
    selectedLearningMode = mode;
    notifyListeners();
  }

  void setQuestionSetup({
    required QuestionGenerationMode generationMode,
    required LearningLevel learningLevel,
  }) {
    selectedGenerationMode = generationMode;
    selectedLearningLevel = learningLevel;
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
      level: selectedLearningLevel.plannerLevel,
      subjectType: subjectType,
      subjectName: currentSubject,
    );

    return QuestionGenerationConfig(
      mode: selectedLearningMode,
      generationMode: selectedGenerationMode,
      learningLevel: selectedLearningLevel,
      subjectType: subjectType,
      allowedTypes: allowedTypes,
      weights: weights,
      level: level,
      count: count,
      usesUploadedMaterial: selectedGenerationMode.requiresMaterial && currentSessionId > 0,
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

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallback;
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
          isLocked: _toBool(map['isLocked'] ?? map['is_locked'], fallback: true),
          isCompleted: _toBool(map['isCompleted'] ?? map['is_completed']),
        );
      }).toList();
    }

    return [];
  }

  Future<void> generateCurriculum(
    String subject,
    int userId, {
    QuestionGenerationMode generationMode = QuestionGenerationMode.aiOnly,
    LearningLevel learningLevel = LearningLevel.beginner,
  }) async {
    isLoading = true;
    selectedGenerationMode = generationMode;
    selectedLearningLevel = learningLevel;
    notifyListeners();

    try {
      final result = await _questionService.generateCurriculum(
        subject: subject,
        userId: userId,
        generationMode: generationMode,
        learningLevel: learningLevel,
      );

      currentSessionId = _toInt(result['sessionId']);
      currentSubject = result['subject'] ?? subject;
      selectedGenerationMode = QuestionGenerationModeX.fromApiValue(result['generation_mode']);
      selectedLearningLevel = LearningLevelX.fromApiValue(result['difficulty'] ?? result['learning_level']);
      lessons = _parseLessons(result['lessons']);
      await fetchUserSessions(userId);
    } catch (e) {
      debugPrint('커리큘럼 생성 실패: $e');
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
    currentSessionId = _toInt(session['id']);
    currentSubject = (session['subject'] ?? session['topic'])?.toString() ?? '';
    selectedGenerationMode = QuestionGenerationModeX.fromApiValue(session['generation_mode'] ?? session['generationMode']);
    selectedLearningLevel = LearningLevelX.fromApiValue(session['difficulty'] ?? session['learning_level']);
    selectedLearningMode = LearningMode.recommended;
    lessons = _parseLessons(session['lessons'] ?? session['curriculum']);
    notifyListeners();
  }

  void loadSessionFromUploadResponse(Map<String, dynamic> response) {
    currentSessionId = _toInt(response['session_id']);
    currentSubject = response['subject']?.toString() ?? '';
    selectedGenerationMode = QuestionGenerationModeX.fromApiValue(
      response['generation_mode'] ?? QuestionGenerationMode.materialOnly.apiValue,
    );
    selectedLearningLevel = LearningLevelX.fromApiValue(response['difficulty']);
    selectedLearningMode = LearningMode.recommended;
    lessons = _parseLessons(response['curriculum']);

    final double uploadedProgress = _toDouble(response['progress']);
    var updated = false;
    userSessions = userSessions.map((session) {
      if (_toInt(session['id']) == currentSessionId) {
        updated = true;
        return {
          ...session,
          'subject': currentSubject,
          'progress': uploadedProgress,
          'lessons': lessons,
          'generation_mode': selectedGenerationMode.apiValue,
          'difficulty': selectedLearningLevel.apiValue,
          'last_studied_at': response['last_studied_at'],
        };
      }
      return session;
    }).toList();

    if (!updated && currentSessionId > 0) {
      userSessions = [
        {
          'id': currentSessionId,
          'subject': currentSubject,
          'progress': uploadedProgress,
          'lessons': lessons,
          'generation_mode': selectedGenerationMode.apiValue,
          'difficulty': selectedLearningLevel.apiValue,
          'last_studied_at': response['last_studied_at'],
        },
        ...userSessions,
      ];
    }

    notifyListeners();
  }

  Future<void> updateCurrentSessionSetup(int userId) async {
    if (currentSessionId <= 0) return;
    await _questionService.updateSessionSetup(
      sessionId: currentSessionId,
      generationMode: selectedGenerationMode,
      learningLevel: selectedLearningLevel,
    );
    await fetchUserSessions(userId);
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
