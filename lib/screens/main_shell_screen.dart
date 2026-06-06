import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'learning/ongoing_learning_screen.dart';
import 'progress/study_calendar_screen.dart';
import 'review/review_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    OngoingLearningScreen(),
    ReviewScreen(),
    StudyCalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF58CC02),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill_rounded), label: '진행 중'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_rounded), label: '오답노트'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: '진행도'),
        ],
      ),
    );
  }
}
