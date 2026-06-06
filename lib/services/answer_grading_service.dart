import '../models/question_model.dart';
import '../models/question_type.dart';
import '../utils/answer_normalizer.dart';

enum AnswerGradeStatus {
  correct,
  partial,
  incorrect,
}

class AnswerGradeResult {
  final AnswerGradeStatus status;
  final double score;
  final String feedback;

  const AnswerGradeResult({
    required this.status,
    required this.score,
    required this.feedback,
  });

  bool get isCorrect => status == AnswerGradeStatus.correct || status == AnswerGradeStatus.partial;
}

class AnswerGradingService {
  AnswerGradeResult grade({
    required QuestionModel question,
    required String userAnswer,
  }) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return _gradeExact(question.answer, userAnswer);
      case QuestionType.shortAnswer:
      case QuestionType.calculation:
      case QuestionType.codeReading:
        return _gradeShortAnswer(question, userAnswer);
      case QuestionType.descriptive:
        return _gradeDescriptive(question, userAnswer);
      case QuestionType.coding:
      case QuestionType.sqlWriting:
      case QuestionType.commandWriting:
        return _gradeExact(question.answer, userAnswer);
    }
  }

  AnswerGradeResult _gradeExact(String expected, String userAnswer) {
    final isCorrect = AnswerNormalizer.isSameAnswer(userAnswer, expected);
    return AnswerGradeResult(
      status: isCorrect ? AnswerGradeStatus.correct : AnswerGradeStatus.incorrect,
      score: isCorrect ? 1.0 : 0.0,
      feedback: isCorrect ? '정답입니다.' : '정답과 일치하지 않습니다.',
    );
  }

  AnswerGradeResult _gradeShortAnswer(QuestionModel question, String userAnswer) {
    final candidates = <String>[
      question.answer,
      question.displayAnswer,
      ...question.acceptableAnswers,
    ].where((answer) => answer.trim().isNotEmpty).toSet();

    for (final candidate in candidates) {
      if (AnswerNormalizer.isSameAnswer(userAnswer, candidate)) {
        return const AnswerGradeResult(
          status: AnswerGradeStatus.correct,
          score: 1.0,
          feedback: '허용 답안과 일치합니다.',
        );
      }
    }

    return const AnswerGradeResult(
      status: AnswerGradeStatus.incorrect,
      score: 0.0,
      feedback: '허용 답안과 의미가 충분히 일치하지 않습니다.',
    );
  }

  AnswerGradeResult _gradeDescriptive(QuestionModel question, String userAnswer) {
    final normalizedUser = AnswerNormalizer.normalize(userAnswer);
    if (normalizedUser.isEmpty) {
      return const AnswerGradeResult(
        status: AnswerGradeStatus.incorrect,
        score: 0.0,
        feedback: '답안이 비어 있습니다.',
      );
    }

    final keywords = question.keywords.where((keyword) => keyword.trim().isNotEmpty).toList();
    final normalizedKeywords = AnswerNormalizer.normalizeAll(keywords);
    final matchedKeywordCount = normalizedKeywords.where(normalizedUser.contains).length;

    if (normalizedKeywords.isNotEmpty) {
      final ratio = matchedKeywordCount / normalizedKeywords.length;
      if (ratio >= 0.6) {
        return AnswerGradeResult(
          status: AnswerGradeStatus.correct,
          score: ratio,
          feedback: '핵심 키워드가 충분히 포함되어 있습니다.',
        );
      }
      if (ratio >= 0.35 || matchedKeywordCount >= 1) {
        return AnswerGradeResult(
          status: AnswerGradeStatus.partial,
          score: ratio,
          feedback: '일부 핵심 키워드가 포함되어 부분 정답으로 인정합니다.',
        );
      }
    }

    final modelAnswer = question.displayAnswer;
    final normalizedModel = AnswerNormalizer.normalize(modelAnswer);
    if (normalizedModel.isNotEmpty) {
      final overlapScore = _characterOverlapScore(normalizedUser, normalizedModel);
      if (overlapScore >= 0.55) {
        return AnswerGradeResult(
          status: AnswerGradeStatus.partial,
          score: overlapScore,
          feedback: '모범답안과 유사한 의미가 일부 포함되어 있습니다.',
        );
      }
    }

    return const AnswerGradeResult(
      status: AnswerGradeStatus.incorrect,
      score: 0.0,
      feedback: '핵심 의미가 충분히 드러나지 않았습니다.',
    );
  }

  double _characterOverlapScore(String userAnswer, String modelAnswer) {
    final userChars = userAnswer.split('').toSet();
    final modelChars = modelAnswer.split('').toSet();
    if (userChars.isEmpty || modelChars.isEmpty) return 0.0;

    final intersection = userChars.intersection(modelChars).length;
    return intersection / modelChars.length;
  }
}
