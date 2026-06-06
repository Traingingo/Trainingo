import '../models/learning_mode.dart';
import '../models/question_type.dart';
import '../models/subject_type.dart';

class SubjectClassifier {
  static SubjectType classify({
    required String subject,
    String? sourcePreview,
  }) {
    final text = '${subject.toLowerCase()} ${sourcePreview?.toLowerCase() ?? ''}';

    const programmingKeywords = [
      'c언어',
      'c language',
      'python',
      'java',
      'javascript',
      'dart',
      'flutter',
      'algorithm',
      '알고리즘',
      '자료구조',
      '프로그래밍',
      '코딩',
    ];

    const practicalKeywords = [
      'database',
      'db',
      'sql',
      '데이터베이스',
      '운영체제',
      '네트워크',
      'web programming',
      '웹프로그래밍',
      'linux',
      '리눅스',
      '명령어',
    ];

    const calculationKeywords = [
      '수학',
      '미적분',
      '선형대수',
      '통계',
      '확률',
      '회로',
      '회로이론',
      '물리',
      '계산',
      '공식',
    ];

    if (programmingKeywords.any(text.contains)) {
      return SubjectType.programming;
    }
    if (practicalKeywords.any(text.contains)) {
      return SubjectType.practical;
    }
    if (calculationKeywords.any(text.contains)) {
      return SubjectType.calculation;
    }
    return SubjectType.conceptual;
  }
}

class SubjectQuestionPolicy {
  static List<QuestionType> allowedTypes(SubjectType subjectType, {String subjectName = ''}) {
    switch (subjectType) {
      case SubjectType.programming:
        return const [
          QuestionType.multipleChoice,
          QuestionType.shortAnswer,
          QuestionType.descriptive,
          QuestionType.codeReading,
          QuestionType.coding,
        ];
      case SubjectType.practical:
        final supportsSql = subjectName.toLowerCase().contains('sql') ||
            subjectName.toLowerCase().contains('database') ||
            subjectName.toLowerCase().contains('db') ||
            subjectName.contains('데이터베이스');
        return [
          QuestionType.multipleChoice,
          QuestionType.shortAnswer,
          QuestionType.descriptive,
          if (supportsSql) QuestionType.sqlWriting,
          QuestionType.commandWriting,
          QuestionType.codeReading,
        ];
      case SubjectType.conceptual:
        return const [
          QuestionType.multipleChoice,
          QuestionType.shortAnswer,
          QuestionType.descriptive,
        ];
      case SubjectType.calculation:
        return const [
          QuestionType.multipleChoice,
          QuestionType.shortAnswer,
          QuestionType.descriptive,
          QuestionType.calculation,
        ];
    }
  }

  static bool supportsCoding(SubjectType type) {
    return allowedTypes(type).contains(QuestionType.coding);
  }

  static bool supportsSqlWriting(SubjectType type, String subjectName) {
    return allowedTypes(type, subjectName: subjectName).contains(QuestionType.sqlWriting);
  }
}

class QuestionTypePlanner {
  static Map<String, int> _baseRatioByLevel(int level) {
    switch (level) {
      case 1:
        return {'multipleChoice': 70, 'shortAnswer': 20, 'descriptive': 10, 'applied': 0};
      case 2:
        return {'multipleChoice': 50, 'shortAnswer': 25, 'descriptive': 20, 'applied': 5};
      case 3:
        return {'multipleChoice': 35, 'shortAnswer': 25, 'descriptive': 30, 'applied': 10};
      case 4:
        return {'multipleChoice': 20, 'shortAnswer': 25, 'descriptive': 35, 'applied': 20};
      default:
        return {'multipleChoice': 10, 'shortAnswer': 20, 'descriptive': 40, 'applied': 30};
    }
  }

  static Map<QuestionType, int> recommendedWeights({
    required int level,
    required SubjectType subjectType,
    required String subjectName,
  }) {
    final base = _baseRatioByLevel(level);
    final applied = base['applied'] ?? 0;
    final weights = <QuestionType, int>{
      QuestionType.multipleChoice: base['multipleChoice']!,
      QuestionType.shortAnswer: base['shortAnswer']!,
      QuestionType.descriptive: base['descriptive']!,
    };

    switch (subjectType) {
      case SubjectType.programming:
        if (applied > 0) {
          final codeReading = (applied * 0.4).round();
          weights[QuestionType.codeReading] = codeReading;
          weights[QuestionType.coding] = applied - codeReading;
        }
        break;
      case SubjectType.practical:
        if (applied > 0) {
          if (SubjectQuestionPolicy.supportsSqlWriting(subjectType, subjectName)) {
            weights[QuestionType.sqlWriting] = applied;
          } else {
            final commandWriting = (applied * 0.6).round();
            weights[QuestionType.commandWriting] = commandWriting;
            weights[QuestionType.codeReading] = applied - commandWriting;
          }
        }
        break;
      case SubjectType.conceptual:
        weights[QuestionType.descriptive] = (weights[QuestionType.descriptive] ?? 0) + applied;
        break;
      case SubjectType.calculation:
        if (applied > 0) {
          weights[QuestionType.calculation] = applied;
        }
        break;
    }

    final allowed = SubjectQuestionPolicy.allowedTypes(subjectType, subjectName: subjectName).toSet();
    weights.removeWhere((type, value) => !allowed.contains(type) || value <= 0);
    return normalizeTo100(weights);
  }

  static Map<QuestionType, int> normalizeTo100(Map<QuestionType, int> weights) {
    final positive = Map<QuestionType, int>.from(weights)..removeWhere((_, value) => value <= 0);
    final total = positive.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return {QuestionType.multipleChoice: 100};
    }

    final entries = positive.entries.toList();
    final normalized = <QuestionType, int>{};
    var used = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final value = i == entries.length - 1 ? 100 - used : ((entry.value / total) * 100).round();
      normalized[entry.key] = value;
      used += value;
    }
    return normalized;
  }
}

class LearningModePlanner {
  static Map<QuestionType, int> buildWeights({
    required LearningMode mode,
    required int level,
    required SubjectType subjectType,
    required String subjectName,
    Map<QuestionType, int>? customWeights,
  }) {
    final allowed = SubjectQuestionPolicy.allowedTypes(subjectType, subjectName: subjectName).toSet();
    Map<QuestionType, int> weights;

    switch (mode) {
      case LearningMode.recommended:
        weights = QuestionTypePlanner.recommendedWeights(
          level: level,
          subjectType: subjectType,
          subjectName: subjectName,
        );
        break;
      case LearningMode.multipleChoiceFocused:
        weights = {
          QuestionType.multipleChoice: 80,
          QuestionType.shortAnswer: 10,
          QuestionType.descriptive: 10,
        };
        break;
      case LearningMode.shortAnswerFocused:
        weights = {
          QuestionType.multipleChoice: 25,
          QuestionType.shortAnswer: 55,
          QuestionType.descriptive: 20,
        };
        break;
      case LearningMode.descriptiveFocused:
        weights = {
          QuestionType.multipleChoice: 15,
          QuestionType.shortAnswer: 25,
          QuestionType.descriptive: 60,
        };
        break;
      case LearningMode.includeCoding:
        weights = QuestionTypePlanner.recommendedWeights(
          level: level,
          subjectType: subjectType,
          subjectName: subjectName,
        );
        if (allowed.contains(QuestionType.coding)) {
          weights[QuestionType.coding] = (weights[QuestionType.coding] ?? 0) + 15;
          weights[QuestionType.multipleChoice] = ((weights[QuestionType.multipleChoice] ?? 0) - 15).clamp(0, 100);
        } else if (allowed.contains(QuestionType.sqlWriting)) {
          weights[QuestionType.sqlWriting] = (weights[QuestionType.sqlWriting] ?? 0) + 15;
          weights[QuestionType.multipleChoice] = ((weights[QuestionType.multipleChoice] ?? 0) - 15).clamp(0, 100);
        }
        break;
      case LearningMode.custom:
        weights = customWeights ?? QuestionTypePlanner.recommendedWeights(
          level: level,
          subjectType: subjectType,
          subjectName: subjectName,
        );
        break;
    }

    weights.removeWhere((type, value) => !allowed.contains(type) || value <= 0);
    return QuestionTypePlanner.normalizeTo100(weights);
  }
}
