import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nicalingo/features/auth/screens/login_screen.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';
import 'package:nicalingo/features/onboarding/screens/language_selection_screen.dart';
import 'package:nicalingo/core/services/update_service.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Comprobar actualizaciones desde GitHub Releases en segundo plano
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });

    // 2. Continuar con la verificación de sesión y navegación
    await _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Mostrar la pantalla de carga inicial
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    final tempEmail = prefs.getString('temp_email');
    final tempPassword = prefs.getString('temp_password');

    Widget targetScreen;

    if (tempEmail != null && tempPassword != null) {
      bool loginSuccess = false;
      int attempts = 0;
      const int maxAttempts = 6;

      while (!loginSuccess && attempts < maxAttempts && mounted) {
        try {
          await supabase.auth.signInWithPassword(
            email: tempEmail,
            password: tempPassword,
          );

          loginSuccess = true;
          await prefs.remove('temp_email');
          await prefs.remove('temp_password');
        } catch (e) {
          attempts++;
          if (attempts < maxAttempts) {
            await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      if (!mounted) return;

      targetScreen = loginSuccess 
          ? const LanguageSelectionScreen() 
          : const LoginScreen();
    } else {
      final session = supabase.auth.currentSession;
      targetScreen = session != null ? const HomeMapScreen() : const LoginScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //usando las letritas de la shari
            Image.asset(
              'assets/images/pantalla_carga.png',
              width: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              strokeWidth: 4.0,
            ),
          ],
        ),
      ),
    );
  }
}