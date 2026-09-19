import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nicalingo/features/auth/models/signup_flow_model.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';
import 'package:nicalingo/features/auth/screens/verify_code_screen.dart';
import 'package:nicalingo/features/auth/screens/profile_capture_screen.dart';

// ============================================================================
// 1. PANTALLA INICIAL (Corregida para Async Gaps)
// ============================================================================
class InitialSplashScreen extends StatefulWidget {
  const InitialSplashScreen({super.key});

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    // Damos tiempo a que se muestre el logo del Splash (2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    // CASO 1: El usuario ya está logueado completamente
    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
      );
      return;
    }

    // CASO 2: Revisamos si dejó la app en la pantalla de verificación
    final prefs = await SharedPreferences.getInstance();
    
    // --> SOLUCIÓN ASYNC GAP: Volvemos a verificar si el widget sigue montado
    // después del await de SharedPreferences
    if (!mounted) return; 

    final isPending = prefs.getBool('pending_verification') ?? false;

    if (isPending) {
      // Reconstruimos sus datos desde la memoria
      final pendingData = SignupFlowModel(
        email: prefs.getString('temp_email') ?? '',
        nickname: prefs.getString('temp_nickname'),
        avatarUrl: prefs.getString('temp_avatar'),
        languageId: prefs.getString('temp_language'),
      );

      // Lo mandamos directo a meter el código
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyCodeScreen(signupData: pendingData),
        ),
      );
      return;
    }

    // CASO 3: Es un usuario totalmente nuevo, va al inicio
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProfileCaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/coco saludo.png', 
                height: 180,
              ),
              const SizedBox(height: 32),
              const Text(
                'Cargando tu aventura...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. PANTALLA DE TRANSICIÓN (Clase añadida para Login y Verify Code)
// ============================================================================
class TransitionSplashScreen extends StatefulWidget {
  final String message;
  final String imagePath;
  final VoidCallback onNavigation;

  const TransitionSplashScreen({
    super.key,
    required this.message,
    required this.imagePath,
    required this.onNavigation,
  });

  @override
  State<TransitionSplashScreen> createState() => _TransitionSplashScreenState();
}

class _TransitionSplashScreenState extends State<TransitionSplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    // Muestra la pantalla por 2 segundos antes de ejecutar la función de navegación
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    widget.onNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                widget.imagePath, 
                height: 180,
              ),
              const SizedBox(height: 32),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}