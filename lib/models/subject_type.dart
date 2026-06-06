enum SubjectType {
  programming,
  practical,
  conceptual,
  calculation,
}

extension SubjectTypeX on SubjectType {
  String get label {
    switch (this) {
      case SubjectType.programming:
        return '프로그래밍';
      case SubjectType.practical:
        return '실습형';
      case SubjectType.conceptual:
        return '개념형';
      case SubjectType.calculation:
        return '계산형';
    }
  }

  static SubjectType fromName(String? value) {
    return SubjectType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => SubjectType.conceptual,
    );
  }
}
