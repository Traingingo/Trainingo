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
  List<Map<String, dynamic>> _answers = [];
  bool _isLoading = true;
  int _expandedId = -1;
  String _subjectFilter = '전체';
  String _typeFilter = '전체';
  String _difficultyFilter = '전체';
  bool _latestFirst = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnswers());
  }

  Future<void> _loadAnswers() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    final list = await _questionService.fetchIncorrectAnswers(user.id);
    if (!mounted) return;
    setState(() {
      _answers = list;
      _isLoading = false;
      _expandedId = -1;
    });
  }

  Future<void> _markReviewed(int id) async {
    final success = await _questionService.deleteIncorrectAnswer(id);
    if (!mounted) return;
    if (success) {
      setState(() {
        _answers.removeWhere((item) => _toInt(item['id']) == id);
        _expandedId = -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 복습 완료! 목록에서 제외되었습니다.'), backgroundColor: Color(0xFF58CC02)),
      );
    }
  }

  List<String> _valuesFor(String key) {
    final values = <String>{'전체'};
    for (final item in _answers) {
      final value = _clean(item[key]);
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList();
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _answers.where((item) {
      final subject = _clean(item['subject'] ?? item['topic']);
      final type = _clean(item['question_type'] ?? item['type']);
      final difficulty = _clean(item['difficulty']);
      return (_subjectFilter == '전체' || subject == _subjectFilter) &&
          (_typeFilter == '전체' || type == _typeFilter) &&
          (_difficultyFilter == '전체' || difficulty == _difficultyFilter);
    }).toList();
    list.sort((a, b) {
      final left = DateTime.tryParse(_clean(a['created_at'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = DateTime.tryParse(_clean(b['created_at'])) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _latestFirst ? right.compareTo(left) : left.compareTo(right);
    });
    return list;
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _filtered) {
      final subject = _clean(item['subject'] ?? item['topic']);
      grouped.putIfAbsent(subject.isEmpty ? '학습 주제 없음' : subject, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _valuesFor('subject');
    final types = _valuesFor('question_type');
    final difficulties = _valuesFor('difficulty');
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('오답노트', style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w900)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3C3C3C)), onPressed: _loadAnswers)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))))
          : RefreshIndicator(
              onRefresh: _loadAnswers,
              child: _answers.isEmpty
                  ? const _EmptyReview()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _FilterPanel(
                          subjects: subjects,
                          types: types,
                          difficulties: difficulties,
                          selectedSubject: subjects.contains(_subjectFilter) ? _subjectFilter : '전체',
                          selectedType: types.contains(_typeFilter) ? _typeFilter : '전체',
                          selectedDifficulty: difficulties.contains(_difficultyFilter) ? _difficultyFilter : '전체',
                          latestFirst: _latestFirst,
                          onSubjectChanged: (value) => setState(() => _subjectFilter = value ?? '전체'),
                          onTypeChanged: (value) => setState(() => _typeFilter = value ?? '전체'),
                          onDifficultyChanged: (value) => setState(() => _difficultyFilter = value ?? '전체'),
                          onSortChanged: (value) => setState(() => _latestFirst = value),
                        ),
                        const SizedBox(height: 16),
                        if (grouped.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(child: Text('선택한 조건에 맞는 오답이 없습니다.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                          )
                        else
                          ...grouped.entries.expand((entry) => [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text('${entry.key} · ${entry.value.length}개', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                                ),
                                ...entry.value.map((item) => _WrongAnswerCard(
                                      item: item,
                                      isExpanded: _expandedId == _toInt(item['id']),
                                      onTap: () => setState(() {
                                        final id = _toInt(item['id']);
                                        _expandedId = _expandedId == id ? -1 : id;
                                      }),
                                      onReviewed: () => _markReviewed(_toInt(item['id'])),
                                    )),
                              ]),
                      ],
                    ),
            ),
    );
  }

  String _clean(dynamic value) => value?.toString().replaceAll(r'\n', '\n').trim() ?? '';

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _FilterPanel extends StatelessWidget {
  final List<String> subjects;
  final List<String> types;
  final List<String> difficulties;
  final String selectedSubject;
  final String selectedType;
  final String selectedDifficulty;
  final bool latestFirst;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onDifficultyChanged;
  final ValueChanged<bool> onSortChanged;

  const _FilterPanel({
    required this.subjects,
    required this.types,
    required this.difficulties,
    required this.selectedSubject,
    required this.selectedType,
    required this.selectedDifficulty,
    required this.latestFirst,
    required this.onSubjectChanged,
    required this.onTypeChanged,
    required this.onDifficultyChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('필터 / 정렬', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 10),
          _Dropdown(label: '학습 주제', value: selectedSubject, values: subjects, onChanged: onSubjectChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Dropdown(label: '문제 유형', value: selectedType, values: types, onChanged: onTypeChanged)),
              const SizedBox(width: 8),
              Expanded(child: _Dropdown(label: '난이도', value: selectedDifficulty, values: difficulties, onChanged: onDifficultyChanged)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: latestFirst,
            title: Text(latestFirst ? '최신순' : '오래된순', style: const TextStyle(fontWeight: FontWeight.bold)),
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  const _Dropdown({required this.label, required this.value, required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final uniqueValues = values.toSet().toList();
    return DropdownButtonFormField<String>(
      value: uniqueValues.contains(value) ? value : '전체',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      items: uniqueValues.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}

class _WrongAnswerCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onReviewed;

  const _WrongAnswerCard({required this.item, required this.isExpanded, required this.onTap, required this.onReviewed});

  @override
  Widget build(BuildContext context) {
    final questionText = _clean(item['question'] ?? item['question_text']);
    final userAnswer = _clean(item['user_answer']);
    final correctAnswer = _firstNonEmpty([item['answer'], item['correct_answer'], item['model_answer'], item['sample_answer'], item['expected_answer']]);
    final explanation = _clean(item['explanation']);
    final type = _clean(item['question_type'] ?? item['type']);
    final difficulty = _clean(item['difficulty']);
    final createdAt = _clean(item['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isExpanded ? const Color(0xFF58CC02) : const Color(0xFFE5E5E5), width: 2)),
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
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (type.isNotEmpty) _Tag(label: type),
                    if (difficulty.isNotEmpty) _Tag(label: difficulty),
                    if (createdAt.isNotEmpty) _Tag(label: _formatDate(createdAt)),
                  ]),
                  const SizedBox(height: 10),
                  Text(questionText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C), height: 1.35)),
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
                  _LabeledBox(label: '내 답안', text: userAnswer.isEmpty ? '저장된 사용자 답안이 없습니다.' : userAnswer, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  _LabeledBox(label: '정답 / 모범답안', text: correctAnswer.isEmpty ? '저장된 정답 또는 모범답안이 없습니다.' : correctAnswer, color: const Color(0xFF46A302)),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _LabeledBox(label: '해설', text: explanation, color: const Color(0xFF1899D6)),
                  ],
                  const SizedBox(height: 16),
                  DuoButton(text: '이해 완료! 목록에서 제외', onPressed: onReviewed),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _clean(dynamic value) => value?.toString().replaceAll(r'\n', '\n').trim() ?? '';

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _clean(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _LabeledBox({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.35, color: Color(0xFF3C3C3C))),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFEAF8E1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF46A302))),
    );
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.emoji_events, size: 80, color: Color(0xFFFFC800)),
        SizedBox(height: 16),
        Text('완벽합니다!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        SizedBox(height: 8),
        Text('저장된 오답이 없습니다.\n틀렸던 문제를 정복하고 오답 노트를 비워보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
