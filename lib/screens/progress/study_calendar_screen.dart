import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/question_service.dart';

class StudyCalendarScreen extends StatefulWidget {
  const StudyCalendarScreen({super.key});

  @override
  State<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends State<StudyCalendarScreen> {
  final QuestionService _questionService = QuestionService();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedDateKey;
  Map<String, Map<String, dynamic>> _recordsByDate = {};
  int _streakDays = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCalendar());
  }

  Future<void> _loadCalendar() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    final data = await _questionService.fetchStudyCalendar(user.id);
    final rawRecords = data['records'] is List ? data['records'] as List : const [];
    final recordsByDate = <String, Map<String, dynamic>>{};
    for (final item in rawRecords) {
      if (item is Map) {
        final record = Map<String, dynamic>.from(item);
        final key = record['study_date']?.toString();
        if (key != null && key.isNotEmpty) {
          recordsByDate[key] = record;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _recordsByDate = recordsByDate;
      _streakDays = _toInt(data['streak_days']);
      _selectedDateKey ??= _dateKey(DateTime.now());
      _isLoading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<DateTime?> _monthCells() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingEmpty = first.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leadingEmpty, null),
      ...List.generate(daysInMonth, (index) => DateTime(_focusedMonth.year, _focusedMonth.month, index + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  void _moveMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecord = _selectedDateKey == null ? null : _recordsByDate[_selectedDateKey!];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('학습 진행도', style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _loadCalendar, icon: const Icon(Icons.refresh, color: Color(0xFF3C3C3C))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Color(0xFFFFF4D6), shape: BoxShape.circle),
                          child: const Icon(Icons.local_fire_department, color: Color(0xFFFF9600), size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('연속 학습일', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text('$_streakDays일 연속', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
                            Expanded(
                              child: Text(
                                '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                              ),
                            ),
                            IconButton(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            _WeekdayLabel('월'),
                            _WeekdayLabel('화'),
                            _WeekdayLabel('수'),
                            _WeekdayLabel('목'),
                            _WeekdayLabel('금'),
                            _WeekdayLabel('토'),
                            _WeekdayLabel('일'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: _monthCells().map((date) {
                            if (date == null) return const SizedBox.shrink();
                            final key = _dateKey(date);
                            final record = _recordsByDate[key];
                            final solved = _toInt(record?['solved_count']);
                            final isSelected = _selectedDateKey == key;
                            final hasStudy = solved > 0;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedDateKey = key;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF58CC02)
                                      : hasStudy
                                          ? const Color(0xFFEAF8E1)
                                          : const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF46A302)
                                        : hasStudy
                                            ? const Color(0xFFB9E8A0)
                                            : const Color(0xFFE5E5E5),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isSelected ? Colors.white : const Color(0xFF3C3C3C),
                                      ),
                                    ),
                                    if (hasStudy) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '$solved문제',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF46A302)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SelectedDaySummary(dateKey: _selectedDateKey, record: selectedRecord),
                ],
              ),
            ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  final String? dateKey;
  final Map<String, dynamic>? record;

  const _SelectedDaySummary({required this.dateKey, required this.record});

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final solved = _toInt(record?['solved_count']);
    final correct = _toInt(record?['correct_count']);
    final wrong = _toInt(record?['wrong_count']);
    final accuracy = solved == 0 ? 0 : ((correct / solved) * 100).round();
    final rawTopics = record?['studied_topics'];
    final topics = rawTopics is List ? rawTopics.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : <String>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateKey ?? '날짜 선택', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 12),
          if (solved == 0)
            const Text('이 날짜에는 아직 학습 기록이 없습니다.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          else ...[
            Row(
              children: [
                Expanded(child: _StatBox(label: '푼 문제', value: '$solved')),
                const SizedBox(width: 8),
                Expanded(child: _StatBox(label: '정답률', value: '$accuracy%')),
                const SizedBox(width: 8),
                Expanded(child: _StatBox(label: '오답', value: '$wrong')),
              ],
            ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('학습한 주제', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics.map((topic) => Chip(label: Text(topic), backgroundColor: const Color(0xFFEAF8E1))).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        ],
      ),
    );
  }
}
