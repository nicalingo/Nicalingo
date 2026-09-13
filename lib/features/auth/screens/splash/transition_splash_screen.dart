import 'package:flutter/material.dart';

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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onNavigation();
      }
    });
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