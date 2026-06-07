import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/question_type.dart';
import '../../providers/auth_provider.dart';
import '../../services/question_service.dart';
import '../../widgets/common/duo_button.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

enum _ReviewSortOrder {
  latest,
  oldest,
}

class _ReviewScreenState extends State<ReviewScreen> {
  final QuestionService _questionService = QuestionService();

  List<Map<String, dynamic>> _incorrectAnswers = [];
  bool _isLoading = true;
  int _expandedIndex = -1;

  String _selectedType = 'all';
  String _selectedDifficulty = 'all';
  _ReviewSortOrder _sortOrder = _ReviewSortOrder.latest;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    final list = await _questionService.fetchIncorrectAnswers(user.id);

    if (!mounted) return;

    setState(() {
      _incorrectAnswers = list;
      _isLoading = false;
      _expandedIndex = -1;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanText(dynamic value) {
    return value?.toString().replaceAll(r'\n', '\n').trim() ?? '';
  }

  String _questionTypeLabel(String value) {
    final type = QuestionTypeX.fromApiValue(value);
    return type.label;
  }

  String _difficultyLabel(String value) {
    return LearningLevelX.fromApiValue(value).label;
  }

  String _answerText(Map<String, dynamic> item) {
    return _cleanText(
      item['answer'] ??
          item['correct_answer'] ??
          item['model_answer'] ??
          item['sample_answer'] ??
          item['expected_answer'],
    );
  }

  DateTime _createdAt(Map<String, dynamic> item) {
    final raw = item['created_at']?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> get _filteredAnswers {
    final filtered = _incorrectAnswers.where((item) {
      final type = _cleanText(item['question_type']);
      final difficulty = _cleanText(item['difficulty']);

      final typeMatch = _selectedType == 'all' || type == _selectedType;
      final difficultyMatch = _selectedDifficulty == 'all' || difficulty == _selectedDifficulty;

      return typeMatch && difficultyMatch;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _createdAt(a);
      final bDate = _createdAt(b);

      if (_sortOrder == _ReviewSortOrder.latest) {
        return bDate.compareTo(aDate);
      }

      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedBySubject {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in _filteredAnswers) {
      final subject = _cleanText(item['subject']).isEmpty ? '학습 주제 없음' : _cleanText(item['subject']);
      grouped.putIfAbsent(subject, () => []);
      grouped[subject]!.add(item);
    }

    return grouped;
  }

  Future<void> _resolveAnswer(int answerId) async {
    final success = await _questionService.deleteIncorrectAnswer(answerId);

    if (!mounted) return;

    if (success) {
      await _loadAnswers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('복습 완료! 오답노트에서 제외되었습니다.'),
          backgroundColor: Color(0xFF58CC02),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오답 삭제에 실패했습니다.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _clearAllAnswers() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('오답노트 전체 삭제'),
          content: const Text(
            '현재 오답노트에 표시된 항목을 모두 삭제할까요?\n\n삭제한 항목은 오답노트 목록에서 사라집니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                '전체 삭제',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    final success = await _questionService.clearIncorrectAnswers(
      userId: user.id,
    );

    if (!mounted) return;

    if (success) {
      await _loadAnswers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오답노트를 비웠습니다.'),
          backgroundColor: Color(0xFF58CC02),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오답노트 삭제에 실패했습니다.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<DropdownMenuItem<String>> _typeItems() {
    return [
      const DropdownMenuItem(value: 'all', child: Text('전체 유형')),
      ...QuestionType.values.map(
            (type) => DropdownMenuItem(
          value: type.apiValue,
          child: Text(type.label),
        ),
      ),
      const DropdownMenuItem(value: 'legacy', child: Text('기존 오답')),
    ];
  }

  List<DropdownMenuItem<String>> _difficultyItems() {
    return [
      const DropdownMenuItem(value: 'all', child: Text('전체 난이도')),
      ...LearningLevel.values.map(
            (level) => DropdownMenuItem(
          value: level.apiValue,
          child: Text(level.label),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedBySubject;
    final filteredAnswers = _filteredAnswers;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '오답노트',
          style: TextStyle(
            color: Color(0xFF3C3C3C),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnswers,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            onPressed: _incorrectAnswers.isEmpty ? null : _clearAllAnswers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
        ),
      )
          : _incorrectAnswers.isEmpty
          ? _EmptyReviewView(onRefresh: _loadAnswers)
          : Column(
        children: [
          _FilterArea(
            selectedType: _selectedType,
            selectedDifficulty: _selectedDifficulty,
            sortOrder: _sortOrder,
            typeItems: _typeItems(),
            difficultyItems: _difficultyItems(),
            onTypeChanged: (value) {
              setState(() {
                _selectedType = value ?? 'all';
                _expandedIndex = -1;
              });
            },
            onDifficultyChanged: (value) {
              setState(() {
                _selectedDifficulty = value ?? 'all';
                _expandedIndex = -1;
              });
            },
            onSortChanged: (value) {
              setState(() {
                _sortOrder = value ?? _ReviewSortOrder.latest;
                _expandedIndex = -1;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '표시 중 ${filteredAnswers.length}개 / 전체 ${_incorrectAnswers.length}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearAllAnswers,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('전체 삭제'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredAnswers.isEmpty
                ? const Center(
              child: Text(
                '필터 조건에 맞는 오답이 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.expand((entry) {
                return [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder,
                          color: Color(0xFF1899D6),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3C3C3C),
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value.length}개',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map((item) {
                    final globalIndex = filteredAnswers.indexOf(item);
                    return _ReviewCard(
                      item: item,
                      isExpanded: _expandedIndex == globalIndex,
                      questionText: _cleanText(item['question_text'] ?? item['question']),
                      correctAnswer: _answerText(item),
                      userAnswer: _cleanText(item['user_answer']),
                      explanation: _cleanText(item['explanation']),
                      questionTypeLabel: _questionTypeLabel(_cleanText(item['question_type'])),
                      difficultyLabel: _difficultyLabel(_cleanText(item['difficulty'])),
                      createdAt: _cleanText(item['created_at']),
                      onTap: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == globalIndex ? -1 : globalIndex;
                        });
                      },
                      onResolve: () => _resolveAnswer(_toInt(item['id'])),
                    );
                  }),
                ];
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyReviewView({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 80,
              color: Color(0xFFFFC800),
            ),
            const SizedBox(height: 16),
            const Text(
              '완벽합니다!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3C3C3C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '저장된 오답이 없습니다.\n틀렸던 문제를 정복하고 오답노트를 비워보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            DuoButton(
              text: '새로고침',
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterArea extends StatelessWidget {
  final String selectedType;
  final String selectedDifficulty;
  final _ReviewSortOrder sortOrder;
  final List<DropdownMenuItem<String>> typeItems;
  final List<DropdownMenuItem<String>> difficultyItems;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onDifficultyChanged;
  final ValueChanged<_ReviewSortOrder?> onSortChanged;

  const _FilterArea({
    required this.selectedType,
    required this.selectedDifficulty,
    required this.sortOrder,
    required this.typeItems,
    required this.difficultyItems,
    required this.onTypeChanged,
    required this.onDifficultyChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedType,
                  isExpanded: true,
                  decoration: _inputDecoration('문제 유형'),
                  items: typeItems,
                  onChanged: onTypeChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  isExpanded: true,
                  decoration: _inputDecoration('난이도'),
                  items: difficultyItems,
                  onChanged: onDifficultyChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<_ReviewSortOrder>(
            value: sortOrder,
            isExpanded: true,
            decoration: _inputDecoration('정렬'),
            items: const [
              DropdownMenuItem(
                value: _ReviewSortOrder.latest,
                child: Text('최신순'),
              ),
              DropdownMenuItem(
                value: _ReviewSortOrder.oldest,
                child: Text('오래된순'),
              ),
            ],
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1.5),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final String questionText;
  final String correctAnswer;
  final String userAnswer;
  final String explanation;
  final String questionTypeLabel;
  final String difficultyLabel;
  final String createdAt;
  final VoidCallback onTap;
  final VoidCallback onResolve;

  const _ReviewCard({
    required this.item,
    required this.isExpanded,
    required this.questionText,
    required this.correctAnswer,
    required this.userAnswer,
    required this.explanation,
    required this.questionTypeLabel,
    required this.difficultyLabel,
    required this.createdAt,
    required this.onTap,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final options = item['options'] is List ? item['options'] as List : <dynamic>[];
    final hasOptions = options.isNotEmpty;

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
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(
                        text: questionTypeLabel,
                        color: const Color(0xFFE1F5FE),
                        textColor: const Color(0xFF0288D1),
                      ),
                      _Badge(
                        text: difficultyLabel,
                        color: const Color(0xFFFFF3E0),
                        textColor: const Color(0xFFEF6C00),
                      ),
                      if (createdAt.isNotEmpty)
                        _Badge(
                          text: createdAt.split('T').first,
                          color: const Color(0xFFF3E5F5),
                          textColor: const Color(0xFF7B1FA2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    questionText.isEmpty ? '문제 내용이 없습니다.' : questionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C3C3C),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasOptions) ...[
                    const Text(
                      '선택 항목 분석',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...options.map((opt) {
                      final optionText = opt.toString();
                      final isCorrect = optionText == correctAnswer;
                      final isUserSelect = optionText == userAnswer;

                      Color cardColor = const Color(0xFFF7F8FA);
                      Color borderColor = const Color(0xFFE5E5E5);
                      IconData? icon;
                      Color? iconColor;
                      Color textColor = const Color(0xFF3C3C3C);

                      if (isCorrect) {
                        cardColor = const Color(0xFFD7FFB7);
                        borderColor = const Color(0xFF58CC02);
                        icon = Icons.check_circle;
                        iconColor = const Color(0xFF46A302);
                        textColor = const Color(0xFF46A302);
                      } else if (isUserSelect) {
                        cardColor = const Color(0xFFFFDFE0);
                        borderColor = Colors.redAccent;
                        icon = Icons.cancel;
                        iconColor = Colors.red;
                        textColor = Colors.red.shade900;
                      }

                      return _AnswerCard(
                        text: optionText,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        icon: icon,
                        iconColor: iconColor,
                        textColor: textColor,
                        isHighlighted: isCorrect || isUserSelect,
                      );
                    }),
                  ] else ...[
                    _LabeledAnswerBox(
                      label: '내 답안',
                      text: userAnswer.isEmpty ? '저장된 사용자 답안이 없습니다.' : userAnswer,
                      backgroundColor: const Color(0xFFFFDFE0),
                      borderColor: Colors.redAccent,
                      textColor: Colors.red.shade900,
                      icon: Icons.cancel,
                    ),
                    const SizedBox(height: 8),
                    _LabeledAnswerBox(
                      label: '정답 / 모범답안',
                      text: correctAnswer.isEmpty ? '저장된 정답 또는 모범답안이 없습니다.' : correctAnswer,
                      backgroundColor: const Color(0xFFD7FFB7),
                      borderColor: const Color(0xFF58CC02),
                      textColor: const Color(0xFF2E7D00),
                      icon: Icons.check_circle,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '해설',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFF59D),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      explanation.isEmpty ? '저장된 해설이 없습니다.' : explanation,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DuoButton(
                    text: '이해 완료! 오답노트에서 삭제',
                    color: const Color(0xFF58CC02),
                    shadowColor: const Color(0xFF46A302),
                    onPressed: onResolve,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String text;
  final Color cardColor;
  final Color borderColor;
  final IconData? icon;
  final Color? iconColor;
  final bool isHighlighted;
  final Color textColor;

  const _AnswerCard({
    required this.text,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    this.icon,
    this.iconColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
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
              text,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
          if (icon != null) Icon(icon, color: iconColor, size: 20),
        ],
      ),
    );
  }
}

class _LabeledAnswerBox extends StatelessWidget {
  final String label;
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;

  const _LabeledAnswerBox({
    required this.label,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}