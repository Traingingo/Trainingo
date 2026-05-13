import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/question_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('단계별 학습'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: learningProvider.lessons.length,
        itemBuilder: (context, index) {
          final lesson = learningProvider.lessons[index];

          return Card(
            child: ListTile(
              leading: Icon(
                lesson.isCompleted
                    ? Icons.check_circle
                    : lesson.isLocked
                    ? Icons.lock
                    : Icons.play_circle,
                color: lesson.isCompleted ? Colors.green : null,
              ),
              title: Text(lesson.title),
              subtitle: Text(lesson.description),
              enabled: !lesson.isLocked,
              onTap: lesson.isLocked
                  ? null
                  : () async {
                final questionProvider =
                context.read<QuestionProvider>();

                await questionProvider.generateQuestions(
                  subject: 'Python',
                  difficulty: '초급',
                  type: '객관식',
                );

                if (!context.mounted) return;
                Navigator.pushNamed(
                  context,
                  AppRoutes.questions,
                  arguments: lesson.id,
                );
              },
            ),
          );
        },
      ),
    );
  }
}