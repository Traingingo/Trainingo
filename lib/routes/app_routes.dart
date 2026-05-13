import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/learning/lesson_list_screen.dart';
import '../screens/learning/question_screen.dart';
import '../screens/materials/material_upload_screen.dart';
import '../screens/review/review_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String lessons = '/lessons';
  static const String questions = '/questions';
  static const String materials = '/materials';
  static const String review = '/review';

  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    home: (_) => const HomeScreen(),
    lessons: (_) => const LessonListScreen(),
    questions: (_) => const QuestionScreen(),
    materials: (_) => const MaterialUploadScreen(),
    review: (_) => const ReviewScreen(),
  };
}