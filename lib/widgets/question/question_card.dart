import 'package:flutter/material.dart';

import '../../models/question_model.dart';

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(question.sourceType)),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            ...question.options.map(
                  (option) => RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: selectedAnswer,
                onChanged: (value) {
                  if (value != null) {
                    onSelected(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}