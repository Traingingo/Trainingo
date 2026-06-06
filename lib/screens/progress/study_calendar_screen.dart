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
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Map<String, dynamic> _calendarData = {'records': [], 'streak_days': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCalendar());
  }

  Future<void> _loadCalendar() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    final data = await _questionService.fetchStudyCalendar(user.id);
    if (!mounted) return;
    setState(() {
      _calendarData = data;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _records {
    final raw = _calendarData['records'];
    if (raw is List) return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    return [];
  }

  Map<String, Map<String, dynamic>> get _recordsByDate {
    final result = <String, Map<String, dynamic>>{};
    for (final record in _records) {
      final key = record['study_date']?.toString() ?? '';
      if (key.isNotEmpty) result[key] = record;
    }
    return result;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _moveMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecord = _recordsByDate[_dateKey(_selectedDate)];
    final streakDays = _toInt(_calendarData['streak_days']);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('학습 진행도 캘린더', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        actions: [IconButton(onPressed: _loadCalendar, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3C3C3C)))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))))
          : RefreshIndicator(
              onRefresh: _loadCalendar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _StreakCard(streakDays: streakDays),
                  const SizedBox(height: 16),
                  _MonthCalendar(
                    focusedMonth: _focusedMonth,
                    selectedDate: _selectedDate,
                    recordsByDate: _recordsByDate,
                    onMoveMonth: _moveMonth,
                    onSelectDate: (date) => setState(() => _selectedDate = date),
                    dateKey: _dateKey,
                  ),
                  const SizedBox(height: 16),
                  _DailyDetailCard(date: _selectedDate, record: selectedRecord),
                ],
              ),
            ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _StreakCard extends StatelessWidget {
  final int streakDays;
  const _StreakCard({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: Color(0xFFFFF3CD), shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9600), size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('연속 학습일', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                const SizedBox(height: 4),
                Text('$streakDays일 연속 학습 중', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<String, Map<String, dynamic>> recordsByDate;
  final ValueChanged<int> onMoveMonth;
  final ValueChanged<DateTime> onSelectDate;
  final String Function(DateTime date) dateKey;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.recordsByDate,
    required this.onMoveMonth,
    required this.onSelectDate,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingBlank = firstDay.weekday % 7;
    final itemCount = leadingBlank + daysInMonth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => onMoveMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(
                  '${focusedMonth.year}년 ${focusedMonth.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                ),
              ),
              IconButton(onPressed: () => onMoveMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const ['일', '월', '화', '수', '목', '금', '토']
                .map((day) => Expanded(child: Center(child: Text(day, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)))))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index < leadingBlank) return const SizedBox.shrink();
              final day = index - leadingBlank + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);
              final key = dateKey(date);
              final record = recordsByDate[key];
              final isSelected = dateKey(selectedDate) == key;
              final solvedCount = _toInt(record?['solved_count']);
              final hasStudy = solvedCount > 0;

              return InkWell(
                onTap: () => onSelectDate(date),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF58CC02)
                        : hasStudy
                            ? const Color(0xFFEAF8E1)
                            : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? const Color(0xFF46A302) : const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? Colors.white : const Color(0xFF3C3C3C))),
                      if (hasStudy)
                        Text('$solvedCount문제', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF46A302))),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _DailyDetailCard extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>? record;

  const _DailyDetailCard({required this.date, required this.record});

  @override
  Widget build(BuildContext context) {
    final solved = _toInt(record?['solved_count']);
    final correct = _toInt(record?['correct_count']);
    final wrong = _toInt(record?['wrong_count']);
    final topics = _topics(record?['studied_topics']);
    final rate = solved == 0 ? 0 : ((correct / solved) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${date.month}월 ${date.day}일 학습 기록', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 12),
          if (solved == 0)
            const Text('이 날짜에는 아직 학습 기록이 없습니다.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          else ...[
            _MetricRow(label: '푼 문제 수', value: '$solved문제'),
            _MetricRow(label: '정답률', value: '$rate%'),
            _MetricRow(label: '정답 / 오답', value: '$correct / $wrong'),
            const SizedBox(height: 8),
            const Text('학습한 주제', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: topics.map((topic) => Chip(label: Text(topic))).toList()),
          ],
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _topics(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) return [];
    return text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        ],
      ),
    );
  }
}
