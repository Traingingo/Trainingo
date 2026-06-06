import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_mode.dart';
import '../../models/question_type.dart';
import '../../models/subject_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/question_policy_service.dart';
import '../../widgets/common/duo_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _subjectController = TextEditingController();
  LearningMode _selectedMode = LearningMode.recommended;

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LearningProvider>().fetchUserSessions(user.id);
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  SubjectType get _subjectType {
    return SubjectClassifier.classify(subject: _subjectController.text.trim());
  }

  List<QuestionType> get _allowedTypes {
    return SubjectQuestionPolicy.allowedTypes(
      _subjectType,
      subjectName: _subjectController.text.trim(),
    );
  }

  bool get _canUseAppliedMode {
    return _allowedTypes.contains(QuestionType.coding) || _allowedTypes.contains(QuestionType.sqlWriting);
  }

  Map<QuestionType, int> get _previewWeights {
    return LearningModePlanner.buildWeights(
      mode: _selectedMode,
      level: 1,
      subjectType: _subjectType,
      subjectName: _subjectController.text.trim(),
    );
  }

  void _generateRoadmap(BuildContext context) async {
    final topic = _subjectController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배우고 싶은 내용을 입력해 주세요!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final provider = context.read<LearningProvider>();
    provider.setSelectedLearningMode(_selectedMode);

    try {
      await provider.generateCurriculum(topic, user.id);
      if (context.mounted && provider.lessons.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.lessons);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final learningProvider = context.watch<LearningProvider>();

    if (learningProvider.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
              ),
              SizedBox(height: 24),
              Text(
                'AI가 맞춤형 학습 로드맵을\n설계하고 있습니다...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, color: Color(0xFF58CC02)),
            SizedBox(width: 8),
            Text(
              'Trainingo AI',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF58CC02),
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Center(child: Icon(Icons.smart_toy, size: 44, color: Colors.white)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                    ),
                    child: Text(
                      '안녕, ${user?.nickname ?? '학습자'}!\n주제와 문제 유형을 고르면 맞춤 학습 코스를 만들어 줄게!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C3C3C),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _NewRoadmapCard(
              subjectController: _subjectController,
              selectedMode: _selectedMode,
              subjectType: _subjectType,
              allowedTypes: _allowedTypes,
              canUseAppliedMode: _canUseAppliedMode,
              previewWeights: _previewWeights,
              onModeChanged: (mode) {
                setState(() {
                  _selectedMode = mode;
                });
              },
              onSubmit: () => _generateRoadmap(context),
            ),
            const SizedBox(height: 24),
            if (learningProvider.userSessions.isNotEmpty) ...[
              const Text(
                '진행 중인 학습 코스 이어하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
              ),
              const SizedBox(height: 12),
              ...learningProvider.userSessions.map((session) {
                final double progress = session['progress'] ?? 0.0;
                final String subject = session['subject'] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFE5E5E5),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                      ),
                      const SizedBox(height: 16),
                      DuoButton(
                        text: '이어서 학습하기',
                        color: const Color(0xFF1899D6),
                        shadowColor: const Color(0xFF147EA9),
                        onPressed: () {
                          context.read<LearningProvider>().loadSession(session);
                          Navigator.pushNamed(context, AppRoutes.lessons);
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: _DuoUtilityCard(
                    title: '오답 노트',
                    icon: Icons.bookmark,
                    iconColor: Colors.redAccent,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.review),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DuoUtilityCard(
                    title: '자료 업로드',
                    icon: Icons.cloud_upload,
                    iconColor: Colors.blueAccent,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.materials),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewRoadmapCard extends StatelessWidget {
  final TextEditingController subjectController;
  final LearningMode selectedMode;
  final SubjectType subjectType;
  final List<QuestionType> allowedTypes;
  final bool canUseAppliedMode;
  final Map<QuestionType, int> previewWeights;
  final ValueChanged<LearningMode> onModeChanged;
  final VoidCallback onSubmit;

  const _NewRoadmapCard({
    required this.subjectController,
    required this.selectedMode,
    required this.subjectType,
    required this.allowedTypes,
    required this.canUseAppliedMode,
    required this.previewWeights,
    required this.onModeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('새로운 주제 학습하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 8),
          const Text('배우고 싶은 분야와 문제 유형을 선택해 주세요.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: subjectController,
            decoration: InputDecoration(
              hintText: '예: 자바 문법 배우기, Flutter 기초',
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('과목 유형: ${subjectType.label}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allowedTypes.map((type) {
              return Chip(
                label: Text(type.label),
                backgroundColor: const Color(0xFFEAF8E1),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF46A302)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text('문제 생성 방식', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 8),
          _ModeTile(mode: LearningMode.recommended, selectedMode: selectedMode, onChanged: onModeChanged),
          _ModeTile(mode: LearningMode.multipleChoiceFocused, selectedMode: selectedMode, onChanged: onModeChanged),
          _ModeTile(mode: LearningMode.shortAnswerFocused, selectedMode: selectedMode, onChanged: onModeChanged),
          _ModeTile(mode: LearningMode.descriptiveFocused, selectedMode: selectedMode, onChanged: onModeChanged),
          if (canUseAppliedMode)
            _ModeTile(
              mode: LearningMode.includeCoding,
              selectedMode: selectedMode,
              onChanged: onModeChanged,
              title: allowedTypes.contains(QuestionType.sqlWriting) ? 'SQL 작성 문제 포함' : '코딩 문제 포함',
            ),
          _ModeTile(mode: LearningMode.custom, selectedMode: selectedMode, onChanged: onModeChanged),
          const SizedBox(height: 12),
          _WeightPreview(weights: previewWeights),
          const SizedBox(height: 16),
          DuoButton(
            text: '학습 로드맵 만들기',
            color: const Color(0xFF58CC02),
            shadowColor: const Color(0xFF46A302),
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final LearningMode mode;
  final LearningMode selectedMode;
  final ValueChanged<LearningMode> onChanged;
  final String? title;

  const _ModeTile({
    required this.mode,
    required this.selectedMode,
    required this.onChanged,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == selectedMode;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF58CC02) : Colors.grey),
      title: Text(title ?? mode.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(mode.description),
      onTap: () => onChanged(mode),
    );
  }
}

class _WeightPreview extends StatelessWidget {
  final Map<QuestionType, int> weights;

  const _WeightPreview({required this.weights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Level 1 예상 문제 비율', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...weights.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Text('${entry.value}%', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1899D6))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DuoUtilityCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _DuoUtilityCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF3C3C3C)),
            ),
          ],
        ),
      ),
    );
  }
}
