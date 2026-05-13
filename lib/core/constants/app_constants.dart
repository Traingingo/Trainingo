class AppConstants {
  static const String appName = 'LearnPath AI';

  // 나중에 Flask/FastAPI 서버 주소로 변경
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  static const List<String> difficulties = [
    '초급',
    '중급',
    '고급',
  ];

  static const List<String> questionTypes = [
    '객관식',
    'OX',
    '단답형',
  ];
}