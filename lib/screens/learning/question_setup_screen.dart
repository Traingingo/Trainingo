import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_setup_options.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class QuestionSetupScreen extends StatefulWidget {
  const QuestionSetupScreen({super.key});

  @override
  State<QuestionSetupScreen> createState() => _QuestionSetupScreenState();
}

class _QuestionSetupScreenState extends State<QuestionSetupScreen> {
  late final TextEditingController _topicController;
  QuestionGenerationMode _generationMode = QuestionGenerationMode.aiOnly;
  LearningLevel _learningLevel = LearningLevel.beginner;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is QuizSetupArgs && _topicController.text.isEmpty) {
      _topicController.text = args.topic;
      _generationMode = args.initialMode;
      _learningLevel = args.initialLevel;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  bool _validate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty && _generationMode != QuestionGenerationMode.materialOnly) {
      setState(() => _errorMessage = 'AI 생성 또는 혼합 생성에는 학습 주제를 입력해 주세요.');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _goNext() async {
    if (!_validate()) return;

    final setup = QuizSetupResult(
      topic: _topicController.text.trim(),
      generationMode: _generationMode,
      learningLevel: _learningLevel,
    );

    context.read<LearningProvider>().setQuizSetup(
          generationMode: setup.generationMode,
          learningLevel: setup.learningLevel,
        );

    if (setup.requiresMaterialUpload) {
      Navigator.pushNamed(context, AppRoutes.materials, arguments: setup);
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final learningProvider = context.read<LearningProvider>();
    try {
      await learningProvider.generateCurriculum(
        setup.topic,
        user.id,
        generationMode: setup.generationMode,
        learningLevel: setup.learningLevel,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.lessons);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<LearningProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('문제 생성 설정', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SetupSection(
                    title: '학습 주제',
                    child: TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        hintText: '예: Flutter 상태관리, 데이터베이스 정규화',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) setState(() => _errorMessage = null);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SetupSection(
                    title: '문제 생성 방식',
                    child: Column(
                      children: QuestionGenerationMode.values.map((mode) {
                        return _SelectableSetupTile(
                          title: mode.label,
                          description: mode.description,
                          icon: mode == QuestionGenerationMode.aiOnly
                              ? Icons.smart_toy_rounded
                              : mode == QuestionGenerationMode.materialOnly
                                  ? Icons.description_rounded
                                  : Icons.auto_awesome_rounded,
                          selected: _generationMode == mode,
                          onTap: () => setState(() => _generationMode = mode),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SetupSection(
                    title: '학습 수준',
                    child: Column(
                      children: LearningLevel.values.map((level) {
                        return _SelectableSetupTile(
                          title: level.label,
                          description: level.description,
                          icon: level == LearningLevel.beginner
                              ? Icons.looks_one_rounded
                              : level == LearningLevel.intermediate
                                  ? Icons.looks_two_rounded
                                  : Icons.looks_3_rounded,
                          selected: _learningLevel == level,
                          onTap: () => setState(() => _learningLevel = level),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 24),
                  DuoButton(
                    text: _generationMode.requiresMaterial ? '자료 업로드로 이동' : '다음',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _goNext,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SetupSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SetupSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SelectableSetupTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableSetupTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? const Color(0xFF58CC02) : const Color(0xFFE5E5E5), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? const Color(0xFF58CC02) : Colors.grey, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF58CC02) : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
