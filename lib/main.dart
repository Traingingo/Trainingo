import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/question_provider.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.initialize();

  runApp(LearnPathApp(authProvider: authProvider));
}

class LearnPathApp extends StatelessWidget {
  final AuthProvider authProvider;

  const LearnPathApp({
    super.key,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => LearningProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Trainingo AI',
            theme: AppTheme.lightTheme,
            onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
              settings,
              auth,
            ),
            onUnknownRoute: (settings) => AppRoutes.onGenerateRoute(
              RouteSettings(
                name: AppRoutes.home,
                arguments: settings.arguments,
              ),
              auth,
            ),
          );
        },
      ),
    );
  }
}
