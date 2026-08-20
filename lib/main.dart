import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/auth/auth_screen.dart';
import 'theme/app_theme.dart';

void main() {
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

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark is what the palette was designed against, but light is a complete
      // second theme rather than an afterthought - so follow the platform
      // instead of forcing one on people who set the other.
      themeMode: ThemeMode.system,

      // The interface is Persian, so the whole layout has to mirror - padding,
      // icon order, list chevrons, the Lektion spine. Without a locale and the
      // delegates, Flutter lays Persian text out left-to-right and every
      // directional affordance points the wrong way.
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AuthScreen(),
    );
  }
}
