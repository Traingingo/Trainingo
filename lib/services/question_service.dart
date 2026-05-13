import '../models/question_model.dart';

class QuestionService {
  Future<List<QuestionModel>> generateQuestions({
    required String subject,
    required String difficulty,
    required String type,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    return [
      QuestionModel(
        id: 1,
        question: '$subject에서 변수란 무엇인가?',
        options: [
          '값을 저장하는 공간',
          '반복문을 실행하는 명령어',
          '화면을 출력하는 함수',
          '오류를 처리하는 문법',
        ],
        answer: '값을 저장하는 공간',
        explanation: '변수는 데이터를 저장하기 위한 이름이 붙은 공간입니다.',
        sourceType: 'AI 생성 문제',
        difficulty: difficulty,
      ),
      QuestionModel(
        id: 2,
        question: '$subject 학습에서 단계별 학습이 필요한 이유는?',
        options: [
          '학습 내용을 체계적으로 익히기 위해',
          '코드를 짧게 쓰기 위해',
          '파일 크기를 줄이기 위해',
          '서버를 종료하기 위해',
        ],
        answer: '학습 내용을 체계적으로 익히기 위해',
        explanation: '단계별 학습은 기초부터 응용까지 자연스럽게 이어지도록 도와줍니다.',
        sourceType: 'AI 생성 문제',
        difficulty: difficulty,
      ),
    ];
  }
}