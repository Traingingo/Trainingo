import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/question_generation_mode.dart';
import '../../models/question_setup_config.dart';
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
  QuestionSetupArguments? _args;
  QuestionGenerationMode _selectedMode = QuestionGenerationMode.aiOnly;
  LearningLevel _selectedLevel = LearningLevel.beginner;
  bool _initialized = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is QuestionSetupArguments) {
      _args = routeArgs;
      _selectedMode = routeArgs.initialMode;
      _selectedLevel = routeArgs.initialLevel;
    } else {
      _args = const QuestionSetupArguments(topic: '');
    }
    _initialized = true;
  }

  bool get _hasUploadedMaterial => _args?.hasUploadedMaterial ?? false;

  Future<void> _goNext() async {
    final args = _args;
    final topic = args?.topic.trim() ?? '';

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 주제를 찾을 수 없습니다. 홈에서 다시 시작해 주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_selectedMode.requiresMaterial && !_hasUploadedMaterial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자료 기반 또는 혼합 생성은 먼저 자료 업로드가 필요합니다.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final learningProvider = context.read<LearningProvider>();
    setState(() {
      _isSubmitting = true;
    });

    try {
      learningProvider.setQuestionSetup(
        generationMode: _selectedMode,
        learningLevel: _selectedLevel,
      );

      final existingSessionId = args?.existingSessionId ?? 0;
      if (existingSessionId > 0) {
        if (learningProvider.currentSessionId != existingSessionId) {
          await learningProvider.fetchUserSessions(user.id);
          Map<String, dynamic>? session;
          for (final candidate in learningProvider.userSessions) {
            if (candidate['id']?.toString() == existingSessionId.toString()) {
              session = candidate;
              break;
            }
          }
          if (session != null) {
            learningProvider.loadSession(session);
          }
        }
        learningProvider.setQuestionSetup(
          generationMode: _selectedMode,
          learningLevel: _selectedLevel,
        );
        await learningProvider.updateCurrentSessionSetup(user.id);
      } else {
        await learningProvider.generateCurriculum(
          topic,
          user.id,
          generationMode: _selectedMode,
          learningLevel: _selectedLevel,
        );
      }

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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _args?.topic.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '문제 생성 설정',
          style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('학습 주제', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      topic.isEmpty ? '주제 없음' : topic,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C)),
                    ),
                    if (_hasUploadedMaterial) ...[
                      const SizedBox(height: 10),
                      const _InfoChip(icon: Icons.description_outlined, text: '업로드 자료 연결됨', color: Color(0xFF1899D6)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('문제 생성 방식', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
              const SizedBox(height: 12),
              ...QuestionGenerationMode.values.map(
                (mode) => _SelectableCard(
                  selected: _selectedMode == mode,
                  enabled: !mode.requiresMaterial || _hasUploadedMaterial,
                  title: mode.label,
                  description: mode.description,
                  icon: mode == QuestionGenerationMode.aiOnly
                      ? Icons.auto_awesome
                      : mode == QuestionGenerationMode.materialOnly
                          ? Icons.description
                          : Icons.hub,
                  onTap: () {
                    if (mode.requiresMaterial && !_hasUploadedMaterial) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이 방식은 자료 업로드 후 선택할 수 있습니다.'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }
                    setState(() {
                      _selectedMode = mode;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text('학습 수준', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
              const SizedBox(height: 12),
              ...LearningLevel.values.map(
                (level) => _SelectableCard(
                  selected: _selectedLevel == level,
                  title: level.label,
                  description: level.description,
                  icon: level == LearningLevel.beginner
                      ? Icons.looks_one
                      : level == LearningLevel.intermediate
                          ? Icons.looks_two
                          : Icons.workspace_premium,
                  onTap: () {
                    setState(() {
                      _selectedLevel = level;
                    });
                  },
                ),
              ),
              const SizedBox(height: 28),
              if (_isSubmitting)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02))),
                      SizedBox(height: 14),
                      Text('선택한 설정으로 학습을 준비하고 있습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                DuoButton(
                  text: '다음',
                  icon: Icons.arrow_forward,
                  color: const Color(0xFF58CC02),
                  shadowColor: const Color(0xFF46A302),
                  onPressed: _goNext,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? const Color(0xFF58CC02) : const Color(0xFFE5E5E5);
    final iconColor = enabled ? (selected ? const Color(0xFF58CC02) : const Color(0xFF1899D6)) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: selected ? 2.5 : 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: enabled ? const Color(0xFF3C3C3C) : Colors.grey)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 12.5, color: enabled ? Colors.grey.shade700 : Colors.grey, height: 1.35)),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
