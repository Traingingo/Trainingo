import 'package:flutter/material.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오답노트'),
      ),
      body: const Center(
        child: Text(
          '아직 저장된 오답이 없습니다.\n나중에 UserAnswer DB와 연결하면 됩니다.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}