import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/lesson_model.dart';
import '../models/question_generation_config.dart';
import '../models/question_model.dart';
import '../models/quiz_setup_options.dart';

class QuestionService {
  final String baseUrl = AppConstants.baseUrl;

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final stringValue = value?.toString().toLowerCase();
    if (stringValue == 'true') return true;
    if (stringValue == 'false') return false;
    return fallback;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  List<LessonModel> _parseLessons(List<dynamic> curriculumJson) {
    return curriculumJson.map((json) {
      final map = Map<String, dynamic>.from(json as Map);
      return LessonModel(
        id: _toInt(map['id']),
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        level: _toInt(map['level'], fallback: 1),
        isLocked: _toBool(map['isLocked'] ?? map['is_locked'], fallback: true),
        isCompleted: _toBool(map['isCompleted'] ?? map['is_completed']),
      );
    }).toList();
  }

  Future<Map<String, dynamic>> generateCurriculum({
    required String subject,
    required int userId,
    required QuestionGenerationMode generationMode,
    required LearningLevel learningLevel,
  }) async {
    final url = Uri.parse('$baseUrl/api/generate-curriculum');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'subject': subject,
          'user_id': userId,
          'generation_mode': generationMode.apiValue,
          'learning_level': learningLevel.apiValue,
          'difficulty': learningLevel.label,
        }),
      );

      final responseData = _decodeMap(response);
      if (response.statusCode == 200) {
        final List<dynamic> curriculumJson = responseData['curriculum'] ?? [];
        return {
          'sessionId': responseData['session_id'] ?? 0,
          'subject': responseData['subject'] ?? subject,
          'progress': _toDouble(responseData['progress']),
          'generation_mode': responseData['generation_mode'] ?? generationMode.apiValue,
          'learning_level': responseData['learning_level'] ?? learningLevel.apiValue,
          'difficulty': responseData['difficulty'] ?? learningLevel.label,
          'lessons': _parseLessons(curriculumJson),
        };
      }
      throw Exception(responseData['detail'] ?? '커리큘럼 생성 에러');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<QuestionModel>> generateQuestions({
    required String subject,
    required String difficulty,
    required QuestionGenerationConfig config,
    int sessionId = 0,
    String levelTitle = '',
    String levelDescription = '',
  }) async {
    final url = Uri.parse('$baseUrl/api/generate-questions');
    final body = <String, dynamic>{
      'subject': subject,
      'difficulty': difficulty,
      'level_title': levelTitle,
      'level_description': levelDescription,
      'session_id': sessionId,
    };
    body.addAll(config.toJson());

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );

      final responseData = _decodeMap(response);
      if (response.statusCode == 200) {
        final List<dynamic> questionsJson = responseData['questions'] ?? [];
        return questionsJson.map((json) => QuestionModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      }
      throw Exception(responseData['detail'] ?? '백엔드 서버 에러: ${response.statusCode}');
    } catch (e) {
      throw Exception('서버 연결에 실패했습니다: $e');
    }
  }

  Future<void> completeLesson({required int sessionId, required int lessonId}) async {
    final url = Uri.parse('$baseUrl/api/complete-lesson');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'session_id': sessionId, 'lesson_id': lessonId}),
      );
      if (response.statusCode != 200) throw Exception('학습 진도 저장 실패');
    } catch (e) {
      print('학습완료 저장실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserSessions(int userId) async {
    final url = Uri.parse('$baseUrl/api/sessions?user_id=$userId');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final responseData = _decodeMap(response);
        final List<dynamic> sessionsJson = responseData['sessions'] ?? [];

        return sessionsJson.map((session) {
          final map = Map<String, dynamic>.from(session as Map);
          final List<dynamic> curriculumJson = map['curriculum'] ?? map['lessons'] ?? [];
          return {
            'id': map['id'],
            'subject': map['subject'] ?? map['topic'],
            'topic': map['topic'] ?? map['subject'],
            'generation_mode': map['generation_mode'] ?? 'ai_only',
            'learning_level': map['learning_level'],
            'difficulty': map['difficulty'] ?? '초급',
            'progress': _toDouble(map['progress']),
            'created_at': map['created_at'],
            'updated_at': map['updated_at'],
            'last_studied_at': map['last_studied_at'],
            'has_material': map['has_material'] ?? false,
            'lessons': _parseLessons(curriculumJson),
          };
        }).toList();
      }
    } catch (e) {
      print('세션목록 조회실패: $e');
    }
    return [];
  }

  Future<void> submitAnswer({
    required int userId,
    required int sessionId,
    required String subject,
    required QuestionModel question,
    required String userAnswer,
    required bool isCorrect,
  }) async {
    final url = Uri.parse('$baseUrl/api/answer-records');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'question_id': question.id,
          'subject': subject,
          'question_type': question.type.apiValue,
          'difficulty': question.difficulty,
          'question_text': question.question,
          'options': question.options,
          'correct_answer': question.answer,
          'model_answer': question.displayAnswer,
          'explanation': question.explanation,
          'user_answer': userAnswer,
          'is_correct': isCorrect,
        }),
      );
    } catch (e) {
      print('풀이 기록 저장 실패: $e');
    }
  }

  Future<void> saveIncorrectAnswer({
    required int userId,
    required String subject,
    required String question,
    required List<String> options,
    required String answer,
    required String explanation,
    required String userAnswer,
    String questionType = 'multiple_choice',
    String difficulty = '초급',
    int sessionId = 0,
    int questionId = 0,
  }) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'question_id': questionId,
          'subject': subject,
          'question_type': questionType,
          'difficulty': difficulty,
          'question': question,
          'options': options,
          'answer': answer,
          'explanation': explanation,
          'user_answer': userAnswer,
        }),
      );
    } catch (e) {
      print('오답 저장 실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchIncorrectAnswers(int userId) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers?user_id=$userId');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final responseData = _decodeMap(response);
        final List<dynamic> answersJson = responseData['answers'] ?? [];
        return answersJson.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (e) {
      print('오답 목록 조회 실패: $e');
    }
    return [];
  }

  Future<bool> deleteIncorrectAnswer(int answerId) async {
    final url = Uri.parse('$baseUrl/api/incorrect-answers/$answerId');
    try {
      final response = await http.delete(url, headers: {'Accept': 'application/json'});
      return response.statusCode == 200;
    } catch (e) {
      print('오답 항목 삭제 실패: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchStudyCalendar(int userId) async {
    final url = Uri.parse('$baseUrl/api/study-calendar?user_id=$userId');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) return _decodeMap(response);
    } catch (e) {
      print('학습 캘린더 조회 실패: $e');
    }
    return {'records': [], 'streak_days': 0};
  }
}
