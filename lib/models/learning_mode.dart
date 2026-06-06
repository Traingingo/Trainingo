enum LearningMode {
  recommended,
  multipleChoiceFocused,
  shortAnswerFocused,
  descriptiveFocused,
  includeCoding,
  custom,
}

extension LearningModeX on LearningMode {
  String get label {
    switch (this) {
      case LearningMode.recommended:
        return '추천 학습 모드';
      case LearningMode.multipleChoiceFocused:
        return '객관식 위주';
      case LearningMode.shortAnswerFocused:
        return '단답형 위주';
      case LearningMode.descriptiveFocused:
        return '서술형 위주';
      case LearningMode.includeCoding:
        return '코딩 문제 포함';
      case LearningMode.custom:
        return '직접 설정';
    }
  }

  String get description {
    switch (this) {
      case LearningMode.recommended:
        return '과목과 레벨에 맞춰 문제 유형 비율을 자동으로 정합니다.';
      case LearningMode.multipleChoiceFocused:
        return '처음 학습하거나 빠르게 복습할 때 좋습니다.';
      case LearningMode.shortAnswerFocused:
        return '핵심 용어를 직접 떠올리는 연습에 좋습니다.';
      case LearningMode.descriptiveFocused:
        return '개념을 문장으로 설명하는 연습에 좋습니다.';
      case LearningMode.includeCoding:
        return '실습형 문제 비중을 높입니다.';
      case LearningMode.custom:
        return '원하는 문제 유형 비율을 직접 조정합니다.';
    }
  }
}
