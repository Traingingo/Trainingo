import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/question_model.dart';
import '../models/lesson_model.dart';

class QuestionService {
  final String baseUrl = AppConstants.baseUrl;

  // 커리큘럼 생성 (세션으로 생성 및 DB 저장)
  Future<Map<String, dynamic>> generateCurriculum({
    required String subject,
    required int userId,
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
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> curriculumJson = responseData['curriculum'] ?? [];
        
        final List<LessonModel> lessons = curriculumJson.map((json) {
          return LessonModel(
            id: json['id'] ?? 0,
            title: json['title']?.toString() ?? '',
            description: json['description']?.toString() ?? '',
            level: json['level'] ?? 1,
            isLocked: json['isLocked'] ?? true,
            isCompleted: json['isCompleted'] ?? false,
          );
        }).toList();

        return {
          "sessionId": responseData['session_id'] ?? 0,
          "subject": responseData['subject'] ?? subject,
          "progress": (responseData['progress'] ?? 0.0) as double,
          "lessons": lessons,
        };
      } else {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMsg = responseData['detail'] ?? "커리큘럼 생성 에러";
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // 퀴즈 문제 생성 (RAG용 session_id 지원)
  Future<List<QuestionModel>> generateQuestions({
    required String subject,
    required String difficulty,
    required String type,
    int sessionId = 0,
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
          "session_id": sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> questionsJson = responseData['questions'] ?? [];

        try {
          return questionsJson.map((json) => QuestionModel.fromJson(json)).toList();
        } catch (modelError) {
          print("❌ [파싱에러] QuestionModel 변환 실패: $modelError");
          throw Exception("데이터 모델 변환 에러 발생: $modelError");
        }
      } else {
        throw Exception("백엔드 서버 에러: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("서버 연결에 실패했습니다: $e");
    }
  }

  // 레벨(단원) 학습 완료 요청
  Future<void> completeLesson({
    required int sessionId,
    required int lessonId,
  }) async {
    final url = Uri.parse('$baseUrl/api/complete-lesson');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "session_id": sessionId,
          "lesson_id": lessonId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("학습 진도 저장 실패");
      }
    } catch (e) {
      print("❌ [학습완료 저장실패]: $e");
    }
  }

  // 사용자 학습 세션 목록 조회 (이어서 학습하기용)
  Future<List<Map<String, dynamic>>> fetchUserSessions(int userId) async {
    final url = Uri.parse('$baseUrl/api/sessions?user_id=$userId');
    try {
      final response = await http.get(url, headers: {"Accept": "application/json"});
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> sessionsJson = responseData['sessions'] ?? [];
        
        return sessionsJson.map((session) {
          final List<dynamic> curriculumJson = session['curriculum'] ?? [];
          final List<LessonModel> lessons = curriculumJson.map((json) {
            return LessonModel(
              id: json['id'] ?? 0,
              title: json['title']?.toString() ?? '',
              description: json['description']?.toString() ?? '',
              level: json['level'] ?? 1,
              isLocked: json['isLocked'] ?? true,
              isCompleted: json['isCompleted'] ?? false,
            );
          }).toList();

          return {
            "id": session['id'],
            "subject": session['subject'],
            "progress": (session['progress'] ?? 0.0) as double,
            "lessons": lessons,
          };
        }).toList();
      }
    } catch (e) {
      print("❌ [세션목록 조회실패]: $e");
    }
    return [];
  }

  // 오답노트 저장 API
  Future<void> saveIncorrectAnswer({
    required int userId,
    required String subject,
    required String question,
    required List<String> options,
    required String answer,
    required String explanation,
    required String userAnswer,
  }) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers');
    try {
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "user_id": userId,
          "subject": subject,
          "question": question,
          "options": options,
          "answer": answer,
          "explanation": explanation,
          "user_answer": userAnswer,
        }),
      );
    } catch (e) {
      print("❌ [오답 저장 실패]: $e");
    }
  }

  // 오답노트 조회 API
  Future<List<Map<String, dynamic>>> fetchIncorrectAnswers(int userId) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers?user_id=$userId');
    try {
      final response = await http.get(url, headers: {"Accept": "application/json"});
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> answersJson = responseData['answers'] ?? [];
        return List<Map<String, dynamic>>.from(answersJson);
      }
    } catch (e) {
      print("❌ [오답 목록 조회 실패]: $e");
    }
    return [];
  }

  // 오답노트 항목 삭제 API
  Future<bool> deleteIncorrectAnswer(int answerId) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers/$answerId');
    try {
      final response = await http.delete(url, headers: {"Accept": "application/json"});
      return response.statusCode == 200;
    } catch (e) {
      print("❌ [오답 항목 삭제 실패]: $e");
      return false;
    }
  }
}