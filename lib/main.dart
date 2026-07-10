import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash_screen.dart'; // <-- Importamos tu nueva pantalla de carga

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicaLingo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryYellow,
        scaffoldBackgroundColor: AppColors.primaryYellow,
        useMaterial3: true, 
      ),
      home: const SplashScreen(),
    );
  }
}