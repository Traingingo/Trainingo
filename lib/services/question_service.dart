import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../models/lesson_model.dart';

class QuestionService {
  // 크롬(Web) 환경이므로 백엔드 서버 주소 그대로 유지
  final String baseUrl = "http://127.0.0.1:8000";

  Future<List<LessonModel>> generateCurriculum({
    required String subject,
  }) async {
    final url = Uri.parse('$baseUrl/api/generate-curriculum');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "subject": subject,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> curriculumJson = responseData['curriculum'] ?? [];

        return curriculumJson.map((json) {
          return LessonModel(
            id: json['id'] ?? 0,
            title: json['title']?.toString() ?? '',
            description: json['description']?.toString() ?? '',
            level: json['level'] ?? 1,
            isLocked: json['isLocked'] ?? true,
            isCompleted: json['isCompleted'] ?? false,
          );
        }).toList();
      } else {
        throw Exception("커리큘럼 생성 에러: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("서버 연결 실패 (커리큘럼): $e");
    }
  }

  Future<List<QuestionModel>> generateQuestions({
    required String subject,
    required String difficulty,
    required String type,
    String levelTitle = "",
    String levelDescription = "",
  }) async {
    final url = Uri.parse('$baseUrl/api/generate-questions');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "subject": subject,
          "difficulty": difficulty,
          "level_title": levelTitle,
          "level_description": levelDescription,
          "count": 3,
        }),
      );

      // 2. 서버 통신 자체가 성공했을 때 (200 OK)
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));

        // 🟢 [로그 출력] 백엔드가 보내준 알몸 상태의 데이터 진짜 모양 확인하기
        print("📥 [통신성공] 백엔드가 전송한 JSON 데이터 원본: $responseData");

        final List<dynamic> questionsJson = responseData['questions'] ?? [];

        try {
          // 🟢 여기서 QuestionModel.fromJson을 하다가 터지면 아래 catch로 잡힘!
          return questionsJson.map((json) => QuestionModel.fromJson(json)).toList();
        } catch (modelError) {
          // 🟢 어떤 변수가 null이거나 타입이 틀렸는지 안스 콘솔에 강제로 실토하게 만들기
          print("❌ [파싱에러] QuestionModel로 변환하다가 터짐! 원인: $modelError");
          print("❌ [파싱에러] 에러가 터진 당시의 JSON 데이터 조각들: $questionsJson");
          throw Exception("데이터 모델 변환 에러 발생: $modelError");
        }

      } else {
        // 서버 측에서 400, 500 등 에러를 반환했을 때
        print("❌ [서버에러] 백엔드가 에러 코드를 뱉었습니다: ${response.statusCode}");
        print("❌ [서버에러] 백엔드 에러 내용: ${response.body}");
        throw Exception("백엔드 서버 에러: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ [최종실패] 네트워크 통신 혹은 런타임 에러 발생: $e");
      throw Exception("서버 연결에 실패했습니다: $e");
    }
  }
}