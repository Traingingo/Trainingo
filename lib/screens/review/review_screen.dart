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

class _ReviewScreenState extends State<ReviewScreen> {
  final QuestionService _questionService = QuestionService();
  List<Map<String, dynamic>> _incorrectAnswers = [];
  bool _isLoading = true;
  int? _expandedId;
  String _subjectFilter = '전체';
  String _typeFilter = '전체';
  String _difficultyFilter = '전체';
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnswers());
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
      _expandedId = null;
    });
  }

  Future<void> _resolveAnswer(int answerId) async {
    final success = await _questionService.deleteIncorrectAnswer(answerId);
    if (success) {
      setState(() {
        _incorrectAnswers.removeWhere((item) => _toInt(item['id']) == answerId);
        _expandedId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 복습 완료! 오답노트에서 제외되었습니다.'),
            backgroundColor: Color(0xFF58CC02),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanText(dynamic value) {
    return value?.toString().replaceAll(r'\n', '\n').trim() ?? '';
  }

  String _subjectOf(Map<String, dynamic> item) {
    final subject = _cleanText(item['subject'] ?? item['topic']);
    return subject.isEmpty ? '학습 주제 없음' : subject;
  }

  String _typeLabelOf(Map<String, dynamic> item) {
    return QuestionTypeX.fromApiValue(item['question_type']?.toString() ?? item['type']?.toString()).label;
  }

  String _difficultyLabelOf(Map<String, dynamic> item) {
    return LearningLevelX.fromApiValue(item['difficulty']).label;
  }

  DateTime _createdAtOf(Map<String, dynamic> item) {
    return DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> get _filteredAnswers {
    final filtered = _incorrectAnswers.where((item) {
      final subjectOk = _subjectFilter == '전체' || _subjectOf(item) == _subjectFilter;
      final typeOk = _typeFilter == '전체' || _typeLabelOf(item) == _typeFilter;
      final difficultyOk = _difficultyFilter == '전체' || _difficultyLabelOf(item) == _difficultyFilter;
      return subjectOk && typeOk && difficultyOk;
    }).toList();

    filtered.sort((a, b) {
      final compare = _createdAtOf(a).compareTo(_createdAtOf(b));
      return _newestFirst ? -compare : compare;
    });
    return filtered;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedAnswers {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _filteredAnswers) {
      groups.putIfAbsent(_subjectOf(item), () => []).add(item);
    }
    return groups;
  }

  List<String> _filterOptions(Iterable<String> values) {
    final options = values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
    return ['전체', ...options];
  }

  @override
  Widget build(BuildContext context) {
    final subjectOptions = _filterOptions(_incorrectAnswers.map(_subjectOf));
    final typeOptions = _filterOptions(_incorrectAnswers.map(_typeLabelOf));
    final difficultyOptions = _filterOptions(_incorrectAnswers.map(_difficultyLabelOf));
    final grouped = _groupedAnswers;

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
              ? const _EmptyReviewView()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _FilterPanel(
                      subjectOptions: subjectOptions,
                      typeOptions: typeOptions,
                      difficultyOptions: difficultyOptions,
                      subjectFilter: _subjectFilter,
                      typeFilter: _typeFilter,
                      difficultyFilter: _difficultyFilter,
                      newestFirst: _newestFirst,
                      onSubjectChanged: (value) => setState(() => _subjectFilter = value),
                      onTypeChanged: (value) => setState(() => _typeFilter = value),
                      onDifficultyChanged: (value) => setState(() => _difficultyFilter = value),
                      onSortChanged: (newestFirst) => setState(() => _newestFirst = newestFirst),
                    ),
                    const SizedBox(height: 16),
                    if (grouped.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('필터 조건에 맞는 오답이 없습니다.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      )
                    else
                      ...grouped.entries.map((entry) {
                        return _SubjectGroup(
                          subject: entry.key,
                          items: entry.value,
                          expandedId: _expandedId,
                          cleanText: _cleanText,
                          typeLabelOf: _typeLabelOf,
                          difficultyLabelOf: _difficultyLabelOf,
                          onToggle: (id) {
                            setState(() {
                              _expandedId = _expandedId == id ? null : id;
                            });
                          },
                          onResolve: _resolveAnswer,
                        );
                      }),
                  ],
                ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final List<String> subjectOptions;
  final List<String> typeOptions;
  final List<String> difficultyOptions;
  final String subjectFilter;
  final String typeFilter;
  final String difficultyFilter;
  final bool newestFirst;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<bool> onSortChanged;

  const _FilterPanel({
    required this.subjectOptions,
    required this.typeOptions,
    required this.difficultyOptions,
    required this.subjectFilter,
    required this.typeFilter,
    required this.difficultyFilter,
    required this.newestFirst,
    required this.onSubjectChanged,
    required this.onTypeChanged,
    required this.onDifficultyChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('필터 및 정렬', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 12),
          _DropdownFilter(label: '학습 주제', value: subjectFilter, options: subjectOptions, onChanged: onSubjectChanged),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _DropdownFilter(label: '문제 유형', value: typeFilter, options: typeOptions, onChanged: onTypeChanged)),
              const SizedBox(width: 10),
              Expanded(child: _DropdownFilter(label: '난이도', value: difficultyFilter, options: difficultyOptions, onChanged: onDifficultyChanged)),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: true, label: Text('최신순'), icon: Icon(Icons.south)),
              ButtonSegment<bool>(value: false, label: Text('오래된순'), icon: Icon(Icons.north)),
            ],
            selected: {newestFirst},
            onSelectionChanged: (selection) => onSortChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _DropdownFilter({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : '전체',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      items: options.map((option) => DropdownMenuItem<String>(value: option, child: Text(option, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _SubjectGroup extends StatelessWidget {
  final String subject;
  final List<Map<String, dynamic>> items;
  final int? expandedId;
  final String Function(dynamic) cleanText;
  final String Function(Map<String, dynamic>) typeLabelOf;
  final String Function(Map<String, dynamic>) difficultyLabelOf;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onResolve;

  const _SubjectGroup({
    required this.subject,
    required this.items,
    required this.expandedId,
    required this.cleanText,
    required this.typeLabelOf,
    required this.difficultyLabelOf,
    required this.onToggle,
    required this.onResolve,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('$subject (${items.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          ),
          ...items.map((item) {
            final id = _toInt(item['id']);
            final isExpanded = expandedId == id;
            final options = item['options'] is List ? item['options'] as List : const [];
            final questionText = cleanText(item['question'] ?? item['question_text']);
            final correctAns = cleanText(item['answer'] ?? item['correct_answer'] ?? item['model_answer'] ?? item['sample_answer'] ?? item['expected_answer']);
            final userAns = cleanText(item['user_answer']);
            final explanation = cleanText(item['explanation']);
            final modelAnswer = cleanText(item['model_answer'] ?? item['sample_answer'] ?? item['expected_answer'] ?? item['answer']);
            final typeLabel = typeLabelOf(item);
            final difficultyLabel = difficultyLabelOf(item);
            final createdAt = cleanText(item['created_at']);

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
                    onTap: () => onToggle(id),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Tag(text: typeLabel, color: const Color(0xFF1899D6)),
                              _Tag(text: difficultyLabel, color: const Color(0xFF58CC02)),
                              if (createdAt.isNotEmpty) _Tag(text: createdAt.split('T').first.split(' ').first, color: Colors.deepPurple),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  questionText,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3C3C3C),
                                  ),
                                ),
                              ),
                              Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                            ],
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
                          if (options.isNotEmpty) ...[
                            const Text('선택 항목 분석', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 8),
                            ...options.map((opt) {
                              final optionText = opt.toString();
                              final isCorrect = optionText == correctAns;
                              final isUserSelect = optionText == userAns;
                              return _AnswerCard(
                                text: optionText,
                                isCorrect: isCorrect,
                                isUserSelect: isUserSelect,
                              );
                            }),
                          ] else ...[
                            const Text('답안 비교', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 8),
                            _LabeledAnswerBox(
                              label: '내가 적은 답',
                              text: userAns.isEmpty ? '저장된 사용자 답안이 없습니다.' : userAns,
                              backgroundColor: const Color(0xFFFFDFE0),
                              borderColor: Colors.redAccent,
                              textColor: Colors.red.shade900,
                              icon: Icons.cancel,
                            ),
                            const SizedBox(height: 8),
                            _LabeledAnswerBox(
                              label: typeLabel == '서술형' ? '모범답안' : '올바른 정답 / 모범답안',
                              text: (typeLabel == '서술형' ? modelAnswer : correctAns).isEmpty ? '저장된 정답 또는 모범답안이 없습니다.' : (typeLabel == '서술형' ? modelAnswer : correctAns),
                              backgroundColor: const Color(0xFFD7FFB7),
                              borderColor: const Color(0xFF58CC02),
                              textColor: const Color(0xFF2E7D00),
                              icon: Icons.check_circle,
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text('해설', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDE7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFF59D), width: 1.5),
                            ),
                            child: Text(
                              explanation.isEmpty ? '저장된 해설이 없습니다.' : explanation,
                              style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DuoButton(
                            text: '이해 완료! 오답노트에서 제외',
                            color: const Color(0xFF58CC02),
                            shadowColor: const Color(0xFF46A302),
                            onPressed: () => onResolve(id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyReviewView extends StatelessWidget {
  const _EmptyReviewView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.emoji_events, size: 80, color: Color(0xFFFFC800)),
            SizedBox(height: 16),
            Text('완벽합니다!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
            SizedBox(height: 8),
            Text('저장된 오답이 없습니다.\n틀렸던 문제를 정복하고 오답 노트를 비워보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String text;
  final bool isCorrect;
  final bool isUserSelect;

  const _AnswerCard({required this.text, required this.isCorrect, required this.isUserSelect});

  @override
  Widget build(BuildContext context) {
    final cardColor = isCorrect
        ? const Color(0xFFD7FFB7)
        : isUserSelect
            ? const Color(0xFFFFDFE0)
            : const Color(0xFFF7F8FA);
    final borderColor = isCorrect
        ? const Color(0xFF58CC02)
        : isUserSelect
            ? Colors.redAccent
            : const Color(0xFFE5E5E5);
    final textColor = isCorrect
        ? const Color(0xFF46A302)
        : isUserSelect
            ? Colors.red.shade900
            : const Color(0xFF3C3C3C);

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
            child: Text(text, style: TextStyle(fontWeight: isCorrect || isUserSelect ? FontWeight.bold : FontWeight.normal, color: textColor)),
          ),
          if (isCorrect) const Icon(Icons.check_circle, color: Color(0xFF46A302), size: 20),
          if (!isCorrect && isUserSelect) const Icon(Icons.cancel, color: Colors.red, size: 20),
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
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}
