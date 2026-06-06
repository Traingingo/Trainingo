import 'learning_level.dart';
import 'question_generation_mode.dart';

class QuestionSetupArguments {
  final String topic;
  final int? existingSessionId;
  final bool fromUploadedMaterial;
  final QuestionGenerationMode initialMode;
  final LearningLevel initialLevel;

  const QuestionSetupArguments({
    required this.topic,
    this.existingSessionId,
    this.fromUploadedMaterial = false,
    this.initialMode = QuestionGenerationMode.aiOnly,
    this.initialLevel = LearningLevel.beginner,
  });

  bool get hasUploadedMaterial => fromUploadedMaterial || (existingSessionId ?? 0) > 0;
}

class QuestionSetupConfig {
  final String topic;
  final QuestionGenerationMode generationMode;
  final LearningLevel learningLevel;
  final int? existingSessionId;
  final bool usesUploadedMaterial;

  const QuestionSetupConfig({
    required this.topic,
    required this.generationMode,
    required this.learningLevel,
    this.existingSessionId,
    this.usesUploadedMaterial = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'generation_mode': generationMode.apiValue,
      'learning_level': learningLevel.apiValue,
      'difficulty': learningLevel.apiValue,
      'session_id': existingSessionId,
      'uses_uploaded_material': usesUploadedMaterial,
    };
  }
}
