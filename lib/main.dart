import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const NicaLingoApp());
}

class NicaLingoApp extends StatelessWidget {
  const NicaLingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicaLingo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}