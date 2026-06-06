import 'question_type.dart';

class QuestionModel {
  final int id;
  final QuestionType type;
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String sourceType;
  final String difficulty;
  final String? code;
  final String? language;
  final String? starterCode;
  final List<Map<String, dynamic>> testCases;
  final List<String> rubric;
  final String? expectedFormat;

  QuestionModel({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.sourceType,
    required this.difficulty,
    this.code,
    this.language,
    this.starterCode,
    this.testCases = const [],
    this.rubric = const [],
    this.expectedFormat,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,
      type: QuestionTypeX.fromApiValue(json['type']?.toString()),
      question: json['question']?.toString() ?? '',
      options: json['options'] != null
          ? List<String>.from(json['options'].map((item) => item.toString()))
          : [],
      answer: json['answer']?.toString() ?? '',
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
      rubric: json['rubric'] is List
          ? List<String>.from(json['rubric'].map((item) => item.toString()))
          : const [],
    );
  }
}
