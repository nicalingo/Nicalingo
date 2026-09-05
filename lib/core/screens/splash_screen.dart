import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nicalingo/features/auth/screens/login_screen.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';
import 'package:nicalingo/features/onboarding/screens/language_selection_screen.dart';
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
    // 1. Mostrar tu pantalla de carga inicial
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    // Leemos las credenciales temporales guardadas durante el registro
    final tempEmail = prefs.getString('temp_email');
    final tempPassword = prefs.getString('temp_password');

    Widget targetScreen;

    // 2. Si hay credenciales temporales pendientes, ejecutamos el inicio de sesión implícito
    if (tempEmail != null && tempPassword != null) {
      bool loginSuccess = false;
      int attempts = 0;
      const int maxAttempts = 6; // 6 intentos x 5s = 30 segundos de espera máxima

      while (!loginSuccess && attempts < maxAttempts && mounted) {
        try {
          // Intento de inicio de sesión implícito
          await supabase.auth.signInWithPassword(
            email: tempEmail,
            password: tempPassword,
          );

          // Si el login pasa, el correo ya está confirmado en Supabase
          loginSuccess = true;

          // Borramos las credenciales temporales
          await prefs.remove('temp_email');
          await prefs.remove('temp_password');
        } catch (e) {
          attempts++;
          if (attempts < maxAttempts) {
            // Espera de 5 segundos entre peticiones para proteger la cuota de la base de datos
            await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      if (!mounted) return;

      // Si inició sesión con éxito, es usuario nuevo: va a elegir idioma
      // Si no logró confirmar a tiempo, lo enviamos al login normal
      targetScreen = loginSuccess 
          ? const LanguageSelectionScreen() 
          : const LoginScreen();
    } else {
      // 3. Flujo original: Si no hay registro pendiente, verificamos si ya existe sesión activa
      final session = supabase.auth.currentSession;
      targetScreen = session != null ? const HomeMapScreen() : const LoginScreen();
    }

    if (!mounted) return;

    // 4. Tu misma transición FadeTransition hacia la pantalla destino
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