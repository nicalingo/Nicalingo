import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/features/auth/screens/login_screen.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';
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
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Esperamos los 3 segundos que tienes configurados para mostrar la pantalla de carga
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Verificamos si Supabase tiene una sesión activa guardada
    final session = Supabase.instance.client.auth.currentSession;
    
    // Determinamos a qué pantalla vamos a navegar
    final Widget targetScreen = session != null ? const HomeMapScreen() : const LoginScreen();

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
            // usando las letritas de la Shari
            Image.asset(
              'assets/images/pantalla_carga.png',
              width: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 50),
            
            // Ruedita de carga
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