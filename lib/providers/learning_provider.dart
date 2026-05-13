import 'package:flutter/material.dart';

import '../models/lesson_model.dart';

class LearningProvider extends ChangeNotifier {
  List<LessonModel> lessons = [
    LessonModel(
      id: 1,
      title: 'Level 1. 기초 개념',
      description: '과목의 기본 개념을 학습합니다.',
      level: 1,
      isLocked: false,
      isCompleted: false,
    ),
    LessonModel(
      id: 2,
      title: 'Level 2. 핵심 문법',
      description: '핵심 문법과 기본 문제를 풉니다.',
      level: 2,
      isLocked: true,
      isCompleted: false,
    ),
    LessonModel(
      id: 3,
      title: 'Level 3. 응용 문제',
      description: '응용 문제를 통해 실력을 확인합니다.',
      level: 3,
      isLocked: true,
      isCompleted: false,
    ),
  ];

  double get progress {
    final completed = lessons.where((lesson) => lesson.isCompleted).length;
    return completed / lessons.length;
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