import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/question_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  void _showLessonDetailBottomSheet(
    BuildContext context,
    dynamic lesson,
    String subject,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 바텀시트 상단 드래그 핸들러
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lesson.isCompleted
                          ? const Color(0xFFFFC800).withOpacity(0.1)
                          : const Color(0xFF1899D6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      lesson.isCompleted
                          ? Icons.emoji_events
                          : Icons.menu_book,
                      color: lesson.isCompleted
                          ? const Color(0xFFFFC800)
                          : const Color(0xFF1899D6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3C3C3C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI 생성 문제 3개 출제',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
                ),
                child: Text(
                  lesson.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4B4B4B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DuoButton(
                text: lesson.isCompleted ? '다시 학습하기' : '학습 시작하기',
                color: const Color(0xFF58CC02),
                shadowColor: const Color(0xFF46A302),
                onPressed: () async {
                  Navigator.pop(context); // 바텀 시트 닫기

                  // 로딩바가 있는 퀴즈 화면으로 가기 전 문제를 미리 요청
                  final questionProvider = context.read<QuestionProvider>();
                  
                  // 비동기로 AI 문제 생성 시작
                  questionProvider.generateQuestions(
                    subject: subject,
                    difficulty: '초급',
                    type: '객관식',
                    levelTitle: lesson.title,
                    levelDescription: lesson.description,
                  );

                  // 퀴즈 화면으로 이동
                  Navigator.pushNamed(
                    context,
                    AppRoutes.questions,
                    arguments: lesson.id,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();
    final lessons = learningProvider.lessons;
    final subject = learningProvider.currentSubject;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: const Color(0xFFE5E5E5),
        title: Text(
          subject.isNotEmpty ? '$subject 학습 경로' : '단계별 학습',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF3C3C3C),
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3C3C3C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: lessons.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      '생성된 커리큘럼이 없습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '홈 화면에서 새로운 학습 주제를 입력해 보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    DuoButton(
                      text: '홈으로 이동',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    )
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 40),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                
                // 지그재그 배치를 위한 정렬 계산
                // 0: 중앙, 1: 왼쪽, 2: 중앙, 3: 오른쪽
                double alignX = 0.0;
                int pos = index % 4;
                if (pos == 1) {
                  alignX = -0.5;
                } else if (pos == 3) {
                  alignX = 0.5;
                }

                // 노드 커넥터 선 (마지막 노드가 아닐 때 아래로 연결선 추가)
                final bool isLast = index == lessons.length - 1;

                return Column(
                  children: [
                    Align(
                      alignment: Alignment(alignX, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: lesson.isLocked
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('이전 레벨을 완료해야 잠금이 해제됩니다!'),
                                        backgroundColor: Color(0xFF3C3C3C),
                                      ),
                                    );
                                  }
                                : () => _showLessonDetailBottomSheet(context, lesson, subject),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 듀오링고 스타일의 3D 원형 물리 버튼 구현
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: lesson.isLocked
                                        ? const Color(0xFFE5E5E5)
                                        : lesson.isCompleted
                                            ? const Color(0xFFFFC800) // 완수 시 골드
                                            : const Color(0xFF58CC02), // 진행 중 시 그린
                                    boxShadow: [
                                      BoxShadow(
                                        color: lesson.isLocked
                                            ? const Color(0xFFB8B8B8)
                                            : lesson.isCompleted
                                                ? const Color(0xFFC79C00)
                                                : const Color(0xFF46A302),
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      lesson.isLocked
                                          ? Icons.lock
                                          : lesson.isCompleted
                                              ? Icons.star
                                              : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 노드 하단 텍스트 레이블
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
                            ),
                            child: Text(
                              lesson.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: lesson.isLocked
                                    ? Colors.grey
                                    : const Color(0xFF3C3C3C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) ...[
                      // 노드 사이의 수직 커넥터 선
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment(alignX, 0),
                        child: Container(
                          width: 8,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
    );
  }
}