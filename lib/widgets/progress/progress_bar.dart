import 'package:flutter/material.dart';

class StudyProgressBar extends StatelessWidget {
  final double progress;

  const StudyProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress,
      minHeight: 10,
      borderRadius: BorderRadius.circular(20),
    );
  }
}