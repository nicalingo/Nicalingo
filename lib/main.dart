import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_text_styles.dart';

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
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icono_app.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                'NicaLingo',
                style: AppTextStyles.titleLargeNoot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}