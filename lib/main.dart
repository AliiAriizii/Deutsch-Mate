import 'package:flutter/material.dart';
import 'screens/auth/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeutschMateApp());
}

class DeutschMateApp extends StatelessWidget {
  const DeutschMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeutschMate',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFFFFCC00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFCC00),
          secondary: Color(0xFFDD0000),
          surface: Color(0xFF1A1A1A),
        ),
      ),
      // ورود به صفحه ثبت‌نام/ورود در ابتدای برنامه
      home: const AuthScreen(),
    );
  }
}