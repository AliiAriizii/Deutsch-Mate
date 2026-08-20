import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/practice/practice_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'theme/app_tokens.dart';

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    LearnScreen(),
    PracticeScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  static const _destinations = [
    (icon: Icons.grid_view_outlined, selected: Icons.grid_view, label: 'خانه'),
    (
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
      label: 'یادگیری'
    ),
    (
      icon: Icons.track_changes_outlined,
      selected: Icons.track_changes,
      label: 'تمرین'
    ),
    (
      icon: Icons.insights_outlined,
      selected: Icons.insights,
      label: 'پیشرفت'
    ),
    (
      icon: Icons.person_outline,
      selected: Icons.person,
      label: 'پروفایل'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's scroll position and exercise state alive
      // across switches; the previous version rebuilt from scratch every time.
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: BorderSide(color: context.colors.hairline),
          ),
        ),
        child: SafeArea(
          top: false,
          // Keeps the bar clear of the home indicator / gesture area rather
          // than letting the system inset eat into the touch targets.
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                  tooltip: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
