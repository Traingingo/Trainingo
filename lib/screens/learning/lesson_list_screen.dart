import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/question_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA), // 듀오링고풍 연한 배경색
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          '단계별 학습 여정',
          style: TextStyle(color: Color(0xFF4B4B4B), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF4B4B4B)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        itemCount: learningProvider.lessons.length,
        itemBuilder: (context, index) {
          final lesson = learningProvider.lessons[index];

          // 💡 지그재그 정렬 알고리즘
          Alignment alignment;
          if (index % 3 == 0) {
            alignment = Alignment.centerLeft;
          } else if (index % 3 == 1) {
            alignment = Alignment.center;
          } else {
            alignment = Alignment.centerRight;
          }

          // 🎨 상태별 차별화 변수 정의
          Color nodeColor;
          Color shadowColor;
          double nodeOpacity = 1.0;

          if (lesson.isCompleted) {
            nodeColor = const Color(0xFF58CC02); // 완료: 듀오링고 초록
            shadowColor = const Color(0xFF46A302);
          } else if (lesson.isLocked) {
            nodeColor = const Color(0xFFE5E5E5); // 잠금: 회색
            shadowColor = const Color(0xFFAFAFAF);
            nodeOpacity = 0.55; // 🔒 잠긴 레벨 반투명화
          } else {
            nodeColor = const Color(0xFF1CB0F6); // 현재 진행 중: 활기찬 파란색
            shadowColor = const Color(0xFF1899D6);
          }

          final isCurrentActive = !lesson.isCompleted && !lesson.isLocked;

          return Column(
            children: [
              // 노드 본체 배치
              Align(
                alignment: alignment,
                child: Opacity(
                  opacity: nodeOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 💡 현재 도전 중인 레벨에만 상단 'START!' 뱃지 띄우기
                      if (isCurrentActive)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1CB0F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'START!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // 둥근 입체 단추 모양의 스테이지 노드
                      GestureDetector(
                        onTap: lesson.isLocked
                            ? null
                            : () async {
                          final questionProvider = context.read<QuestionProvider>();

                          await questionProvider.generateQuestions(
                            subject: 'Python',
                            difficulty: '초급',
                            type: '객관식',
                          );

                          if (!context.mounted) return;
                          Navigator.pushNamed(
                            context,
                            AppRoutes.questions,
                            arguments: lesson.id,
                          );
                        },
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: nodeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              lesson.isCompleted
                                  ? Icons.check_circle_outline
                                  : lesson.isLocked
                                  ? Icons.lock_outline
                                  : Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 스테이지 말풍선 / 텍스트 타이틀
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                        ),
                        child: Text(
                          lesson.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: lesson.isLocked ? Colors.grey : const Color(0xFF4B4B4B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 💡 노드 사이를 연결해 주는 수직 기둥 경로(Path)
              if (index < learningProvider.lessons.length - 1)
                Align(
                  alignment: alignment,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 84,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 50,
                        decoration: BoxDecoration(
                          color: lesson.isCompleted
                              ? const Color(0xFF58CC02)
                              : const Color(0xFFE5E5E5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}