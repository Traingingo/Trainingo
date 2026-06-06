import 'package:flutter/material.dart';

import '../../models/question_model.dart';
import '../../models/question_type.dart';
import 'question_card.dart';

class QuestionCardDispatcher extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onChanged;
  final bool isLocked;

  const QuestionCardDispatcher({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return QuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onSelected: isLocked ? (_) {} : onChanged,
        );
      case QuestionType.shortAnswer:
        return _TextQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          maxLines: 1,
          hintText: '정답을 짧게 입력하세요',
        );
      case QuestionType.descriptive:
        return _TextQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          maxLines: 6,
          hintText: '개념을 문장으로 설명해 보세요',
        );
      case QuestionType.codeReading:
        return _CodeLikeQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '출력 결과 또는 코드의 의미를 입력하세요',
        );
      case QuestionType.coding:
        return _CodeLikeQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '코드를 작성하세요',
          maxLines: 14,
        );
      case QuestionType.sqlWriting:
        return _CodeLikeQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: 'SQL 문을 작성하세요',
          maxLines: 8,
        );
      case QuestionType.commandWriting:
        return _CodeLikeQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '명령어를 작성하세요',
          maxLines: 5,
        );
      case QuestionType.calculation:
        return _TextQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          maxLines: 3,
          hintText: '계산 과정 또는 최종 답을 입력하세요',
        );
    }
  }
}

class _TextQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onChanged;
  final bool isLocked;
  final int maxLines;
  final String hintText;

  const _TextQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
    required this.isLocked,
    required this.maxLines,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuestionHeader(question: question),
          const SizedBox(height: 24),
          TextField(
            enabled: !isLocked,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1899D6), width: 2),
              ),
            ),
          ),
          if (question.rubric.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RubricBox(rubric: question.rubric),
          ],
        ],
      ),
    );
  }
}

class _CodeLikeQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onChanged;
  final bool isLocked;
  final String hintText;
  final int maxLines;

  const _CodeLikeQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
    required this.isLocked,
    required this.hintText,
    this.maxLines = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuestionHeader(question: question),
          if ((question.code ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _CodeBlock(text: question.code!),
          ],
          if ((question.starterCode ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _CodeBlock(text: question.starterCode!),
          ],
          const SizedBox(height: 18),
          TextField(
            enabled: !isLocked,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF1899D6), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final QuestionModel question;

  const _QuestionHeader({required this.question});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFF58CC02), shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    question.type.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF46A302),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3C3C3C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;

  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', height: 1.4),
      ),
    );
  }
}

class _RubricBox extends StatelessWidget {
  final List<String> rubric;

  const _RubricBox({required this.rubric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('채점 기준', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...rubric.map((item) => Text('• $item')),
        ],
      ),
    );
  }
}
