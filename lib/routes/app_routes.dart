import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/learning/lesson_list_screen.dart';
import '../screens/learning/question_screen.dart';
import '../screens/learning/question_setup_screen.dart';
import '../screens/main_shell_screen.dart';
import '../screens/materials/material_upload_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String quizSetup = '/quiz-setup';
  static const String lessons = '/lessons';
  static const String questions = '/questions';
  static const String materials = '/materials';

  static final Set<String> _protectedRoutes = {
    home,
    quizSetup,
    lessons,
    questions,
    materials,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings, AuthProvider authProvider) {
    final requestedRoute = settings.name ?? root;
    final normalizedRoute = requestedRoute == root ? _entryRoute(authProvider) : requestedRoute;

    if (!authProvider.isLoggedIn && _protectedRoutes.contains(normalizedRoute)) {
      return _buildRoute(login, const LoginScreen(), RouteSettings(name: login, arguments: settings.arguments));
    }

    if (authProvider.isLoggedIn && normalizedRoute == login) {
      return _buildRoute(home, const MainShellScreen(), RouteSettings(name: home, arguments: settings.arguments));
    }

    switch (normalizedRoute) {
      case login:
        return _buildRoute(login, const LoginScreen(), settings);
      case home:
        return _buildRoute(home, const MainShellScreen(), settings);
      case quizSetup:
        return _buildRoute(quizSetup, const QuestionSetupScreen(), settings);
      case lessons:
        return _buildRoute(lessons, const LessonListScreen(), settings);
      case questions:
        return _buildRoute(questions, const QuestionScreen(), settings);
      case materials:
        return _buildRoute(materials, const MaterialUploadScreen(), settings);
      default:
        return _buildRoute(
          authProvider.isLoggedIn ? home : login,
          authProvider.isLoggedIn ? const MainShellScreen() : const LoginScreen(),
          settings,
        );
    }
  }

  static String _entryRoute(AuthProvider authProvider) => authProvider.isLoggedIn ? home : login;

  static MaterialPageRoute<dynamic> _buildRoute(String routeName, Widget page, RouteSettings originalSettings) {
    return MaterialPageRoute(
      settings: RouteSettings(name: routeName, arguments: originalSettings.arguments),
      builder: (_) => page,
    );
  }
}
