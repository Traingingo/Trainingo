import 'package:flutter/material.dart';

import '../../models/question_model.dart';
import '../../models/question_type.dart';
import 'resettable_answer_text_field.dart';

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

  String get _resetKey => '${question.id}-${question.type.name}-${question.question.hashCode}';

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return _MultipleChoiceQuestionCard(
          question: question,
          selectedAnswer: selectedAnswer,
          onSelected: onChanged,
          isLocked: isLocked,
        );
      case QuestionType.shortAnswer:
        return _TextQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          maxLines: 1,
          hintText: '정답을 짧게 입력하세요',
        );
      case QuestionType.descriptive:
        return _TextQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          maxLines: 6,
          hintText: '개념을 문장으로 설명해 보세요',
        );
      case QuestionType.codeReading:
        return _CodeLikeQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '출력 결과 또는 코드의 의미를 입력하세요',
        );
      case QuestionType.coding:
        return _CodeLikeQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '코드를 작성하세요',
          maxLines: 14,
        );
      case QuestionType.sqlWriting:
        return _CodeLikeQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: 'SQL 문을 작성하세요',
          maxLines: 8,
        );
      case QuestionType.commandWriting:
        return _CodeLikeQuestionCard(
          resetKey: _resetKey,
          question: question,
          selectedAnswer: selectedAnswer,
          onChanged: onChanged,
          isLocked: isLocked,
          hintText: '명령어를 작성하세요',
          maxLines: 5,
        );
      case QuestionType.calculation:
        return _TextQuestionCard(
          resetKey: _resetKey,
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

class _MultipleChoiceQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onSelected;
  final bool isLocked;

  const _MultipleChoiceQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onSelected,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuestionHeader(question: question),
          const SizedBox(height: 30),
          ...List.generate(question.options.length, (index) {
            final option = question.options[index];
            final isSelected = selectedAnswer == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: isLocked ? null : () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDDF4FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1899D6) : const Color(0xFFE5E5E5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? const Color(0xFF1899D6).withOpacity(0.3) : Colors.black.withOpacity(0.02),
                        offset: const Offset(0, 3),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF1899D6) : const Color(0xFFF7F8FA),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF147EA9) : const Color(0xFFE5E5E5),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.replaceAll(r'\n', '\n'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? const Color(0xFF1899D6) : const Color(0xFF4B4B4B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TextQuestionCard extends StatelessWidget {
  final String resetKey;
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onChanged;
  final bool isLocked;
  final int maxLines;
  final String hintText;

  const _TextQuestionCard({
    required this.resetKey,
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
          ResettableAnswerTextField(
            resetKey: resetKey,
            value: selectedAnswer,
            enabled: !isLocked,
            maxLines: maxLines,
            hintText: hintText,
            onChanged: onChanged,
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
  final String resetKey;
  final QuestionModel question;
  final String? selectedAnswer;
  final ValueChanged<String> onChanged;
  final bool isLocked;
  final String hintText;
  final int maxLines;

  const _CodeLikeQuestionCard({
    required this.resetKey,
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
          ResettableAnswerTextField(
            resetKey: resetKey,
            value: selectedAnswer,
            enabled: !isLocked,
            maxLines: maxLines,
            hintText: hintText,
            style: const TextStyle(fontFamily: 'monospace'),
            onChanged: onChanged,
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
    final parts = _QuestionTextParser.parse(question.question);
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
                if (parts.prompt.isNotEmpty)
                  Text(
                    parts.prompt,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3C3C3C),
                      height: 1.4,
                    ),
                  ),
                if (parts.codeBlocks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...parts.codeBlocks.map(
                    (code) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CodeBlock(text: code),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionTextParts {
  final String prompt;
  final List<String> codeBlocks;
  const _QuestionTextParts({required this.prompt, required this.codeBlocks});
}

class _QuestionTextParser {
  static _QuestionTextParts parse(String rawText) {
    final text = rawText.replaceAll(r'\n', '\n').replaceAll('\\`\\`\\`', '```').trim();
    final codeBlocks = <String>[];
    var prompt = text;

    final fenceRegex = RegExp(r'```[a-zA-Z0-9_+-]*\s*([\s\S]*?)```');
    final matches = fenceRegex.allMatches(text).toList();
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final code = match.group(1)?.trim();
        if (code != null && code.isNotEmpty) {
          codeBlocks.add(code);
        }
      }
      prompt = text.replaceAll(fenceRegex, '').trim();
      return _QuestionTextParts(prompt: _cleanupPrompt(prompt), codeBlocks: codeBlocks);
    }

    final lines = text.split('\n');
    final promptLines = <String>[];
    final codeLines = <String>[];
    for (final line in lines) {
      if (_looksLikeCode(line)) {
        codeLines.add(line);
      } else {
        promptLines.add(line);
      }
    }

    if (codeLines.length >= 2 || (codeLines.isNotEmpty && text.contains('\n'))) {
      codeBlocks.add(codeLines.join('\n').trim());
      prompt = promptLines.join('\n').trim();
    }
    return _QuestionTextParts(prompt: _cleanupPrompt(prompt), codeBlocks: codeBlocks);
  }

  static String _cleanupPrompt(String value) {
    return value.replaceAll(RegExp(r'\n{3,}'), '\n\n').replaceAll(RegExp(r'\s+$', multiLine: true), '').trim();
  }

  static bool _looksLikeCode(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return lower.startsWith('#include') ||
        lower.startsWith('import ') ||
        lower.startsWith('from ') ||
        lower.startsWith('select ') ||
        lower.startsWith('create ') ||
        lower.startsWith('insert ') ||
        lower.startsWith('update ') ||
        lower.startsWith('delete ') ||
        lower.startsWith('def ') ||
        lower.startsWith('class ') ||
        lower.startsWith('for ') ||
        lower.startsWith('while ') ||
        lower.startsWith('if ') ||
        lower.startsWith('else') ||
        lower.contains('printf(') ||
        lower.contains('scanf(') ||
        lower.contains('print(') ||
        lower.contains('console.log') ||
        lower.contains('void main') ||
        lower.contains('int main') ||
        lower.endsWith(';') ||
        trimmed == '{' ||
        trimmed == '}' ||
        trimmed.startsWith('}') ||
        trimmed.endsWith('{');
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text.replaceAll(r'\n', '\n'),
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', height: 1.4, fontSize: 13),
        ),
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
