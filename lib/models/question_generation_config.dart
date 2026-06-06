import 'learning_level.dart';
import 'learning_mode.dart';
import 'question_generation_mode.dart';
import 'question_type.dart';
import 'subject_type.dart';

class QuestionGenerationConfig {
  final LearningMode mode;
  final QuestionGenerationMode generationMode;
  final LearningLevel learningLevel;
  final SubjectType subjectType;
  final List<QuestionType> allowedTypes;
  final Map<QuestionType, int> weights;
  final int level;
  final int count;
  final bool usesUploadedMaterial;

  const QuestionGenerationConfig({
    required this.mode,
    required this.subjectType,
    required this.allowedTypes,
    required this.weights,
    required this.level,
    this.generationMode = QuestionGenerationMode.aiOnly,
    this.learningLevel = LearningLevel.beginner,
    this.count = 10,
    this.usesUploadedMaterial = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'generation_mode': generationMode.apiValue,
      'learning_level': learningLevel.apiValue,
      'uses_uploaded_material': usesUploadedMaterial,
      'subject_type': subjectType.name,
      'allowed_question_types': allowedTypes.map((type) => type.apiValue).toList(),
      'question_type_weights': weights.map(
        (type, weight) => MapEntry(type.apiValue, weight),
      ),
      'level': level,
      'lesson_level': level,
      'count': count,
    };
  }
}
