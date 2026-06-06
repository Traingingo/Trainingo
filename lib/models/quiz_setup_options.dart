import 'learning_mode.dart';

enum LearningLevel {
  beginner,
  intermediate,
  advanced,
}

extension LearningLevelX on LearningLevel {
  String get apiValue {
    switch (this) {
      case LearningLevel.beginner:
        return 'beginner';
      case LearningLevel.intermediate:
        return 'intermediate';
      case LearningLevel.advanced:
        return 'advanced';
    }
  }

  String get label {
    switch (this) {
      case LearningLevel.beginner:
        return '초급';
      case LearningLevel.intermediate:
        return '중급';
      case LearningLevel.advanced:
        return '고급';
    }
  }

  String get description {
    switch (this) {
      case LearningLevel.beginner:
        return '핵심 개념 확인, 객관식·단답형 중심의 쉬운 문제';
      case LearningLevel.intermediate:
        return '개념 적용과 예시 상황 문제를 섞은 균형형 문제';
      case LearningLevel.advanced:
        return '응용·분석·서술형과 과목별 실전형 문제 비중 증가';
    }
  }

  int get policyLevel {
    switch (this) {
      case LearningLevel.beginner:
        return 1;
      case LearningLevel.intermediate:
        return 3;
      case LearningLevel.advanced:
        return 5;
    }
  }

  LearningMode get defaultLearningMode => LearningMode.recommended;

  static LearningLevel fromApiValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'beginner':
      case 'easy':
      case '초급':
        return LearningLevel.beginner;
      case 'intermediate':
      case 'medium':
      case '중급':
        return LearningLevel.intermediate;
      case 'advanced':
      case 'hard':
      case '고급':
        return LearningLevel.advanced;
      default:
        return LearningLevel.beginner;
    }
  }
}

enum QuestionGenerationMode {
  aiOnly,
  materialOnly,
  mixed,
}

extension QuestionGenerationModeX on QuestionGenerationMode {
  String get apiValue {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return 'ai_only';
      case QuestionGenerationMode.materialOnly:
        return 'material_only';
      case QuestionGenerationMode.mixed:
        return 'mixed';
    }
  }

  String get label {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return 'AI 자체 생성';
      case QuestionGenerationMode.materialOnly:
        return '업로드한 자료 기반 생성';
      case QuestionGenerationMode.mixed:
        return 'AI + 자료 혼합 생성';
    }
  }

  String get shortLabel {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return 'AI';
      case QuestionGenerationMode.materialOnly:
        return '자료';
      case QuestionGenerationMode.mixed:
        return '혼합';
    }
  }

  String get description {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return '주제와 일반 지식을 바탕으로 AI가 문제를 만듭니다.';
      case QuestionGenerationMode.materialOnly:
        return '업로드한 자료 내용에 근거해서 문제를 만듭니다.';
      case QuestionGenerationMode.mixed:
        return '자료 내용을 우선하되 AI의 배경지식으로 보강합니다.';
    }
  }

  bool get requiresMaterial => this == QuestionGenerationMode.materialOnly || this == QuestionGenerationMode.mixed;

  static QuestionGenerationMode fromApiValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'ai_only':
      case 'aionly':
      case 'ai':
        return QuestionGenerationMode.aiOnly;
      case 'material_only':
      case 'materialonly':
      case 'document':
      case '자료':
        return QuestionGenerationMode.materialOnly;
      case 'mixed':
      case 'ai_material':
      case 'hybrid':
      case '혼합':
        return QuestionGenerationMode.mixed;
      default:
        return QuestionGenerationMode.aiOnly;
    }
  }
}

class QuizSetupArgs {
  final String topic;
  final QuestionGenerationMode initialMode;
  final LearningLevel initialLevel;

  const QuizSetupArgs({
    this.topic = '',
    this.initialMode = QuestionGenerationMode.aiOnly,
    this.initialLevel = LearningLevel.beginner,
  });
}

class QuizSetupResult {
  final String topic;
  final QuestionGenerationMode generationMode;
  final LearningLevel learningLevel;

  const QuizSetupResult({
    required this.topic,
    required this.generationMode,
    required this.learningLevel,
  });

  bool get requiresMaterialUpload => generationMode.requiresMaterial;

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'generation_mode': generationMode.apiValue,
      'learning_level': learningLevel.apiValue,
      'difficulty': learningLevel.label,
    };
  }
}
