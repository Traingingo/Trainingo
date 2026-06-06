import 'learning_mode.dart';
import 'question_type.dart';
import 'subject_type.dart';

class QuestionGenerationConfig {
  final LearningMode mode;
  final SubjectType subjectType;
  final List<QuestionType> allowedTypes;
  final Map<QuestionType, int> weights;
  final int level;
  final int count;

  const QuestionGenerationConfig({
    required this.mode,
    required this.subjectType,
    required this.allowedTypes,
    required this.weights,
    required this.level,
    this.count = 10,
  });

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'subject_type': subjectType.name,
      'allowed_question_types': allowedTypes.map((type) => type.apiValue).toList(),
      'question_type_weights': weights.map(
        (type, weight) => MapEntry(type.apiValue, weight),
      ),
      'level': level,
      'count': count,
    };
  }
}
