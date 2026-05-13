class QuestionModel {
  final int id;
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String sourceType;
  final String difficulty;

  QuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.sourceType,
    required this.difficulty,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      answer: json['answer'],
      explanation: json['explanation'],
      sourceType: json['source_type'],
      difficulty: json['difficulty'],
    );
  }
}