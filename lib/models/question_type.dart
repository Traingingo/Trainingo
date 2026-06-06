enum QuestionType {
  multipleChoice,
  shortAnswer,
  descriptive,
  codeReading,
  coding,
  sqlWriting,
  commandWriting,
  calculation,
}

extension QuestionTypeX on QuestionType {
  String get apiValue {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.descriptive:
        return 'descriptive';
      case QuestionType.codeReading:
        return 'code_reading';
      case QuestionType.coding:
        return 'coding';
      case QuestionType.sqlWriting:
        return 'sql_writing';
      case QuestionType.commandWriting:
        return 'command_writing';
      case QuestionType.calculation:
        return 'calculation';
    }
  }

  String get label {
    switch (this) {
      case QuestionType.multipleChoice:
        return '객관식';
      case QuestionType.shortAnswer:
        return '단답형';
      case QuestionType.descriptive:
        return '서술형';
      case QuestionType.codeReading:
        return '코드 해석형';
      case QuestionType.coding:
        return '코딩형';
      case QuestionType.sqlWriting:
        return 'SQL 작성형';
      case QuestionType.commandWriting:
        return '명령어 작성형';
      case QuestionType.calculation:
        return '계산형';
    }
  }

  static QuestionType fromApiValue(String? value) {
    return QuestionType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}
