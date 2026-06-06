import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_mode.dart';
import '../../models/question_generation_config.dart';
import '../../models/question_type.dart';
import '../../models/subject_type.dart';
import '../../providers/question_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/question_policy_service.dart';
import '../../widgets/common/duo_button.dart';

class QuestionModeSelectionSheet extends StatefulWidget {
  final String subject;
  final dynamic lesson;
  final int sessionId;

  const QuestionModeSelectionSheet({
    super.key,
    required this.subject,
    required this.lesson,
    required this.sessionId,
  });

  @override
  State<QuestionModeSelectionSheet> createState() => _QuestionModeSelectionSheetState();
}

class _QuestionModeSelectionSheetState extends State<QuestionModeSelectionSheet> {
  LearningMode selectedMode = LearningMode.recommended;
  late SubjectType subjectType;
  late List<QuestionType> allowedTypes;

  int get level => widget.lesson.level is int ? widget.lesson.level as int : 1;

  @override
  void initState() {
    super.initState();
    subjectType = SubjectClassifier.classify(subject: widget.subject);
    allowedTypes = SubjectQuestionPolicy.allowedTypes(subjectType, subjectName: widget.subject);
  }

  Map<QuestionType, int> get currentWeights {
    return LearningModePlanner.buildWeights(
      mode: selectedMode,
      level: level,
      subjectType: subjectType,
      subjectName: widget.subject,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUseAppliedMode = allowedTypes.contains(QuestionType.coding) || allowedTypes.contains(QuestionType.sqlWriting);
    final weights = currentWeights;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '문제 유형을 선택하세요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.subject} 과목은 ${subjectType.label} 과목으로 판단했습니다. Level $level에 맞춰 문제 유형 비율을 조정합니다.',
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allowedTypes
                    .map(
                      (type) => Chip(
                        label: Text(type.label),
                        backgroundColor: const Color(0xFFEAF8E1),
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF46A302)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _modeTile(LearningMode.recommended),
              _modeTile(LearningMode.multipleChoiceFocused),
              _modeTile(LearningMode.shortAnswerFocused),
              _modeTile(LearningMode.descriptiveFocused),
              if (canUseAppliedMode)
                _modeTile(
                  LearningMode.includeCoding,
                  title: allowedTypes.contains(QuestionType.sqlWriting) ? 'SQL 작성 문제 포함' : '코딩 문제 포함',
                ),
              _modeTile(LearningMode.custom),
              const SizedBox(height: 16),
              _WeightPreview(weights: weights),
              const SizedBox(height: 24),
              DuoButton(
                text: '이 설정으로 시작하기',
                color: const Color(0xFF58CC02),
                shadowColor: const Color(0xFF46A302),
                onPressed: _startLearning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTile(LearningMode mode, {String? title}) {
    final selected = selectedMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? const Color(0xFF58CC02) : Colors.grey,
      ),
      title: Text(title ?? mode.label, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(mode.description),
      onTap: () {
        setState(() {
          selectedMode = mode;
        });
      },
    );
  }

  Future<void> _startLearning() async {
    final config = QuestionGenerationConfig(
      mode: selectedMode,
      subjectType: subjectType,
      allowedTypes: allowedTypes,
      weights: currentWeights,
      level: level,
      count: 10,
    );

    final questionProvider = context.read<QuestionProvider>();
    await questionProvider.generateQuestions(
      subject: widget.subject,
      difficulty: '초급',
      config: config,
      sessionId: widget.sessionId,
      levelTitle: widget.lesson.title,
      levelDescription: widget.lesson.description,
    );

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.questions, arguments: widget.lesson.id);
  }
}

class _WeightPreview extends StatelessWidget {
  final Map<QuestionType, int> weights;

  const _WeightPreview({required this.weights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('예상 문제 비율', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...weights.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Text('${entry.value}%', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1899D6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
