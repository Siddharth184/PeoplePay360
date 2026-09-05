import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PeoplePay360App());
}

class PeoplePay360App extends StatelessWidget {
  const PeoplePay360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeoplePay 360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

