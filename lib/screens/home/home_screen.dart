import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/duo_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _subjectController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  void _generateRoadmap(BuildContext context) async {
    final topic = _subjectController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('배우고 싶은 내용을 입력해 주세요! (예: 자바 문법)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final provider = context.read<LearningProvider>();
    await provider.generateCurriculum(topic);

    if (context.mounted) {
      if (provider.lessons.isNotEmpty) {
        Navigator.pushNamed(context, AppRoutes.lessons);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('커리큘럼을 생성하는 데 실패했습니다. 다시 시도해 주세요.'),
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
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 듀오링고 스타일의 귀여운 로딩 애니메이션/캐릭터 표현
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF84D8FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'AI가 맞춤형 학습 로드맵을\n설계하고 있습니다...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C3C3C),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '잠시만 기다려주시면 듀오링고 스타일의\n코스가 완성됩니다!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58CC02)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, color: Color(0xFF58CC02)),
            const SizedBox(width: 8),
            Text(
              'Trainingo AI',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF58CC02),
                fontSize: 22,
                letterSpacing: -0.5,
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
            // 1. 캐릭터 말풍선 웰컴 영역
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 캐릭터 영역 (원형 로봇 또는 아바타)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.smart_toy,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 말풍선
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
                      '안녕, ${user?.nickname ?? '학습자'}! 반가워.\n무엇이든 입력하면 나만의 듀오링고 학습 코스를 만들어 줄게!',
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

            // 2. 새로운 주제 입력창
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '새로운 주제 학습하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3C3C3C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '배우고 싶은 분야나 키워드를 입력해 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: '예: 자바 문법 배우기, Flutter 기초',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E5E5),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF58CC02),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DuoButton(
                    text: '학습 로드맵 만들기',
                    color: const Color(0xFF58CC02),
                    shadowColor: const Color(0xFF46A302),
                    onPressed: () => _generateRoadmap(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. 현재 학습 코스 이어하기 (코스가 존재할 때만 표시)
            if (learningProvider.lessons.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFC800), // 금메달 노랑
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '진행 중인 학습 코스',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                learningProvider.currentSubject,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF3C3C3C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 프로그레스 바
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: learningProvider.progress,
                              minHeight: 12,
                              backgroundColor: const Color(0xFFE5E5E5),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF58CC02),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(learningProvider.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3C3C3C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DuoButton(
                      text: '이어서 학습하기',
                      color: const Color(0xFF1899D6), // 파란색 버튼
                      shadowColor: const Color(0xFF147EA9),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.lessons);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 4. 기타 유틸리티 카드들
            Row(
              children: [
                Expanded(
                  child: _DuoUtilityCard(
                    title: '오답 노트',
                    icon: Icons.bookmark,
                    iconColor: Colors.redAccent,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.review);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DuoUtilityCard(
                    title: '자료 업로드',
                    icon: Icons.cloud_upload,
                    iconColor: Colors.blueAccent,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.materials);
                    },
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
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFF3C3C3C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}