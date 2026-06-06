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
        return '개념 적용, 예시 상황, 객관식·단답형·서술형 혼합';
      case LearningLevel.advanced:
        return '응용·분석·서술형과 과목별 실습형 문제 강화';
    }
  }

  int get plannerLevel {
    switch (this) {
      case LearningLevel.beginner:
        return 1;
      case LearningLevel.intermediate:
        return 3;
      case LearningLevel.advanced:
        return 5;
    }
  }

  static LearningLevel fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'beginner':
      case 'easy':
      case '초급':
        return LearningLevel.beginner;
      case 'intermediate':
      case 'medium':
      case 'normal':
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
