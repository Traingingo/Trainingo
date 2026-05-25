import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/question_service.dart';
import '../../widgets/common/duo_button.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final QuestionService _questionService = QuestionService();
  List<Map<String, dynamic>> _incorrectAnswers = [];
  bool _isLoading = true;
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  void _loadAnswers() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    final list = await _questionService.fetchIncorrectAnswers(user.id);
    
    setState(() {
      _incorrectAnswers = list;
      _isLoading = false;
      _expandedIndex = -1;
    });
  }

  void _resolveAnswer(int answerId, int index) async {
    final success = await _questionService.deleteIncorrectAnswer(answerId);
    if (success) {
      setState(() {
        _incorrectAnswers.removeAt(index);
        _expandedIndex = -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 학습 완료! 오답노트에서 제외되었습니다.'),
            backgroundColor: Color(0xFF58CC02),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '오답노트',
          style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnswers,
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
              ),
            )
          : _incorrectAnswers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.emoji_events, size: 80, color: Color(0xFFFFC800)),
                        SizedBox(height: 16),
                        Text(
                          '완벽합니다!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '저장된 오답이 없습니다.\n틀렸던 문제를 정복하고 오답 노트를 비워보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _incorrectAnswers.length,
                  itemBuilder: (context, index) {
                    final item = _incorrectAnswers[index];
                    final bool isExpanded = _expandedIndex == index;
                    final List<dynamic> options = item['options'] ?? [];
                    final String questionText = item['question'] ?? '';
                    final String correctAns = item['answer'] ?? '';
                    final String userAns = item['user_answer'] ?? '';
                    final String explanation = item['explanation'] ?? '';
                    final String subject = item['subject'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isExpanded ? const Color(0xFF58CC02) : const Color(0xFFE5E5E5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단 탭 헤더 (질문 및 과목명)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedIndex = isExpanded ? -1 : index;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE1F5FE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          subject,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0288D1),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    questionText,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3C3C3C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 확장 영역 (상세 분석)
                          if (isExpanded) ...[
                            const Divider(height: 1, color: Color(0xFFE5E5E5)),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 보기 옵션 리스트 렌더링
                                  const Text(
                                    '선택 항목 분석',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  ...options.map((opt) {
                                    final bool isCorrect = opt.toString() == correctAns;
                                    final bool isUserSelect = opt.toString() == userAns;

                                    Color cardColor = const Color(0xFFF7F8FA);
                                    Color borderColor = const Color(0xFFE5E5E5);
                                    IconData? icon;
                                    Color? iconColor;

                                    if (isCorrect) {
                                      cardColor = const Color(0xFFD7FFB7); // 초록 배경
                                      borderColor = const Color(0xFF58CC02);
                                      icon = Icons.check_circle;
                                      iconColor = const Color(0xFF46A302);
                                    } else if (isUserSelect) {
                                      cardColor = const Color(0xFFFFDFE0); // 빨강 배경
                                      borderColor = Colors.redAccent;
                                      icon = Icons.cancel;
                                      iconColor = Colors.red;
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor, width: 2),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              opt.toString(),
                                              style: TextStyle(
                                                fontWeight: isCorrect || isUserSelect ? FontWeight.bold : FontWeight.normal,
                                                color: isCorrect
                                                    ? const Color(0xFF46A302)
                                                    : isUserSelect
                                                        ? Colors.red.shade900
                                                        : const Color(0xFF3C3C3C),
                                              ),
                                            ),
                                          ),
                                          if (icon != null) Icon(icon, color: iconColor, size: 20),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  const SizedBox(height: 16),
                                  // 해설 박스
                                  const Text(
                                    'AI 오답 분석 해설',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFDE7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFFFF59D), width: 1.5),
                                    ),
                                    child: Text(
                                      explanation,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // 해결 완료 버튼
                                  DuoButton(
                                    text: '이해 완료! 오답노트에서 삭제',
                                    color: const Color(0xFF58CC02),
                                    shadowColor: const Color(0xFF46A302),
                                    onPressed: () => _resolveAnswer(item['id'], index),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}