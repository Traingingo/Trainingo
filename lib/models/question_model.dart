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
      // 🟢 [해결책] id가 null이거나 문자열로 들어와도 안전하게 숫자로 변환하고, 없으면 0이나 기본값 처리!
      id: json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0,

      // 혹시라도 다른 텍스트 데이터들이 null로 들어올 때를 대비해 문자열 안전망도 추가!
      question: json['question']?.toString() ?? '',

      // 보기(options) 리스트 안전하게 가져오기
      options: json['options'] != null
          ? List<String>.from(json['options'].map((item) => item.toString()))
          : [],

      answer: json['answer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'AI', // 기본값 AI
      difficulty: json['difficulty']?.toString() ?? '중',  // 기본값 중
    );
  }
}