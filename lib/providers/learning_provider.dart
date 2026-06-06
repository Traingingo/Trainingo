import 'package:flutter/material.dart';

import '../models/learning_mode.dart';
import '../models/lesson_model.dart';
import '../models/question_generation_config.dart';
import '../models/quiz_setup_options.dart';
import '../services/question_policy_service.dart';
import '../services/question_service.dart';

class LearningProvider extends ChangeNotifier {
  final QuestionService _questionService = QuestionService();

  List<LessonModel> lessons = [];
  String currentSubject = '';
  int currentSessionId = 0;
  bool isLoading = false;
  LearningMode selectedLearningMode = LearningMode.recommended;
  QuestionGenerationMode selectedGenerationMode = QuestionGenerationMode.aiOnly;
  LearningLevel selectedLearningLevel = LearningLevel.beginner;
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

  void setQuizSetup({required QuestionGenerationMode generationMode, required LearningLevel learningLevel}) {
    selectedGenerationMode = generationMode;
    selectedLearningLevel = learningLevel;
    selectedLearningMode = learningLevel.defaultLearningMode;
    notifyListeners();
  }

  QuestionGenerationConfig buildQuestionConfigForLevel(int level, {int count = 10}) {
    final subjectType = SubjectClassifier.classify(subject: currentSubject);
    final allowedTypes = SubjectQuestionPolicy.allowedTypes(subjectType, subjectName: currentSubject);
    final policyLevel = selectedLearningLevel.policyLevel + (level - 1);
    final weights = LearningModePlanner.buildWeights(
      mode: selectedLearningMode,
      level: policyLevel,
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
      level: policyLevel,
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

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }

  List<LessonModel> _parseLessons(dynamic rawLessons) {
    if (rawLessons is List) {
      return rawLessons.where((item) => item is LessonModel || item is Map).map((item) {
        if (item is LessonModel) return item;
        final map = Map<String, dynamic>.from(item as Map);
        final rawLevel = _toInt(map['level']);
        return LessonModel(
          id: _toInt(map['id']),
          title: map['title']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
          level: rawLevel == 0 ? 1 : rawLevel,
          isLocked: _toBool(map['isLocked'] ?? map['is_locked'], fallback: true),
          isCompleted: _toBool(map['isCompleted'] ?? map['is_completed']),
        );
      }).toList();
    }
    return [];
  }

  LearningLevel _readLearningLevel(Map<String, dynamic> map) {
    final rawLevel = map['learning_level']?.toString();
    if (rawLevel != null && rawLevel.trim().isNotEmpty) return learningLevelFromApiValue(rawLevel);
    return learningLevelFromApiValue(map['difficulty']?.toString());
  }

  QuestionGenerationMode _readGenerationMode(Map<String, dynamic> map) {
    return questionGenerationModeFromApiValue(map['generation_mode']?.toString());
  }

  Future<void> generateCurriculum(
    String subject,
    int userId, {
    QuestionGenerationMode? generationMode,
    LearningLevel? learningLevel,
  }) async {
    if (generationMode != null && learningLevel != null) {
      setQuizSetup(generationMode: generationMode, learningLevel: learningLevel);
    }

    isLoading = true;
    notifyListeners();

    try {
      final result = await _questionService.generateCurriculum(
        subject: subject,
        userId: userId,
        generationMode: selectedGenerationMode,
        learningLevel: selectedLearningLevel,
      );
      currentSessionId = _toInt(result['sessionId']);
      currentSubject = result['subject'] ?? subject;
      lessons = _parseLessons(result['lessons']);
      await fetchUserSessions(userId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserSessions(int userId) async {
    userSessions = await _questionService.fetchUserSessions(userId);
    notifyListeners();
  }

  void loadSession(Map<String, dynamic> session) {
    currentSessionId = _toInt(session['id']);
    currentSubject = (session['subject'] ?? session['topic'])?.toString() ?? '';
    selectedGenerationMode = _readGenerationMode(session);
    selectedLearningLevel = _readLearningLevel(session);
    selectedLearningMode = selectedLearningLevel.defaultLearningMode;
    lessons = _parseLessons(session['lessons'] ?? session['curriculum']);
    notifyListeners();
  }

  void loadSessionFromUploadResponse(Map<String, dynamic> response) {
    currentSessionId = _toInt(response['session_id']);
    currentSubject = response['subject']?.toString() ?? '';
    selectedGenerationMode = _readGenerationMode(response);
    selectedLearningLevel = _readLearningLevel(response);
    selectedLearningMode = selectedLearningLevel.defaultLearningMode;
    lessons = _parseLessons(response['curriculum']);

    final uploadedProgress = _toDouble(response['progress']);
    final newSession = {
      'id': currentSessionId,
      'subject': currentSubject,
      'progress': uploadedProgress,
      'lessons': lessons,
      'generation_mode': selectedGenerationMode.apiValue,
      'learning_level': selectedLearningLevel.apiValue,
      'difficulty': selectedLearningLevel.label,
    };

    var updated = false;
    userSessions = userSessions.map((session) {
      if (_toInt(session['id']) == currentSessionId) {
        updated = true;
        return {...session, ...newSession};
      }
      return session;
    }).toList();
    if (!updated && currentSessionId > 0) userSessions = [newSession, ...userSessions];
    notifyListeners();
  }

  Future<void> completeLesson(int lessonId) async {
    LessonModel? completedLesson;
    for (final lesson in lessons) {
      if (lesson.id == lessonId) completedLesson = lesson;
    }
    final nextLevel = completedLesson == null ? null : completedLesson.level + 1;

    lessons = lessons.map((lesson) {
      if (lesson.id == lessonId) {
        return LessonModel(id: lesson.id, title: lesson.title, description: lesson.description, level: lesson.level, isLocked: false, isCompleted: true);
      }
      if (nextLevel != null && lesson.level == nextLevel) {
        return LessonModel(id: lesson.id, title: lesson.title, description: lesson.description, level: lesson.level, isLocked: false, isCompleted: lesson.isCompleted);
      }
      return lesson;
    }).toList();

    notifyListeners();

    if (currentSessionId > 0) {
      await _questionService.completeLesson(sessionId: currentSessionId, lessonId: lessonId);
    }
  }
}
