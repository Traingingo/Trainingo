export 'question_type.dart';

import 'question_type.dart';

class QuestionModel {
  final int id;
  final QuestionType type;
  final String question;
  final List<String> options;
  final String answer;
  final List<String> acceptableAnswers;
  final String explanation;
  final String sourceType;
  final String difficulty;
  final String? code;
  final String? language;
  final String? starterCode;
  final List<Map<String, dynamic>> testCases;
  final List<String> rubric;
  final String? expectedFormat;
  final String? modelAnswer;
  final String? sampleAnswer;
  final String? expectedAnswer;
  final List<String> keywords;
  final String? gradingCriteria;

  QuestionModel({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.answer,
    this.acceptableAnswers = const [],
    required this.explanation,
    required this.sourceType,
    required this.difficulty,
    this.code,
    this.language,
    this.starterCode,
    this.testCases = const [],
    this.rubric = const [],
    this.expectedFormat,
    this.modelAnswer,
    this.sampleAnswer,
    this.expectedAnswer,
    this.keywords = const [],
    this.gradingCriteria,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final type = QuestionTypeX.fromApiValue(json['type']?.toString());
    final answer = json['answer']?.toString() ?? '';
    final modelAnswer = _firstNonEmpty([
      json['model_answer'],
      json['modelAnswer'],
      json['sample_answer'],
      json['sampleAnswer'],
      json['expected_answer'],
      json['expectedAnswer'],
      answer,
    ]);

    return QuestionModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      type: type,
      question: json['question']?.toString() ?? '',
      options: json['options'] != null
          ? List<String>.from(json['options'].map((item) => item.toString()))
          : [],
      answer: answer.isNotEmpty ? answer : (type == QuestionType.descriptive ? modelAnswer : ''),
      acceptableAnswers: _toStringList(json['acceptable_answers'] ?? json['acceptableAnswers']),
      explanation: json['explanation']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'AI',
      difficulty: json['difficulty']?.toString() ?? '중',
      code: json['code']?.toString(),
      language: json['language']?.toString(),
      starterCode: json['starter_code']?.toString(),
      expectedFormat: json['expected_format']?.toString(),
      testCases: json['test_cases'] is List
          ? List<Map<String, dynamic>>.from(
              (json['test_cases'] as List).whereType<Map>().map(
                    (item) => Map<String, dynamic>.from(item),
                  ),
            )
          : const [],
      rubric: _toStringList(json['rubric']),
      modelAnswer: modelAnswer,
      sampleAnswer: _firstNonEmpty([json['sample_answer'], json['sampleAnswer']]),
      expectedAnswer: _firstNonEmpty([json['expected_answer'], json['expectedAnswer']]),
      keywords: _toStringList(json['keywords']),
      gradingCriteria: _firstNonEmpty([json['grading_criteria'], json['gradingCriteria']]),
    );
  }

  String get displayAnswer {
    if (type == QuestionType.descriptive) {
      return _firstNonEmpty([modelAnswer, sampleAnswer, expectedAnswer, answer]);
    }
    return answer;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
