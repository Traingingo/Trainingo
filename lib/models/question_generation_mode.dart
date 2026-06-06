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

  String get description {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return '입력한 주제를 바탕으로 AI가 일반 지식을 활용해 문제를 만듭니다.';
      case QuestionGenerationMode.materialOnly:
        return '업로드한 자료 안의 내용만 근거로 문제를 만듭니다.';
      case QuestionGenerationMode.mixed:
        return '업로드한 자료를 우선 활용하고 AI 지식으로 보완합니다.';
    }
  }

  bool get requiresMaterial {
    switch (this) {
      case QuestionGenerationMode.aiOnly:
        return false;
      case QuestionGenerationMode.materialOnly:
      case QuestionGenerationMode.mixed:
        return true;
    }
  }

  static QuestionGenerationMode fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'ai_only':
      case 'aionly':
      case 'ai':
      case 'ai 자체 생성':
        return QuestionGenerationMode.aiOnly;
      case 'material_only':
      case 'materialonly':
      case 'document':
      case 'document_only':
      case 'upload':
      case '업로드한 자료 기반 생성':
      case '자료 기반':
        return QuestionGenerationMode.materialOnly;
      case 'mixed':
      case 'ai_material':
      case 'ai_plus_material':
      case 'ai + 자료 혼합 생성':
        return QuestionGenerationMode.mixed;
      default:
        return QuestionGenerationMode.aiOnly;
    }
  }
}
