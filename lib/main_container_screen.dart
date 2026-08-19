import 'package:flutter/material.dart';
import 'package:deutsch_mate/screens/home/home_screen.dart';
import 'package:deutsch_mate/screens/learn/learn_screen.dart';
import 'package:deutsch_mate/screens/practice/practice_screen.dart';
import 'package:deutsch_mate/screens/progress/progress_screen.dart';
import 'package:deutsch_mate/screens/profile/profile_screen.dart';

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const LearnScreen(),
    const PracticeScreen(),
    const ProgressScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF141414),
        selectedItemColor: const Color(0xFFFFCC00),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'خانه'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'یادگیری'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_esports_rounded), label: 'تمرین'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'پیشرفت'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'پروفایل'),
        ],
      ),
    );
  }
}