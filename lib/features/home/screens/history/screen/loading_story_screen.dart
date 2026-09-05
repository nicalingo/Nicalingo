import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/history/screen/story_reader_screen.dart';

class LoadingStoryScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  final int storyNumber;

  const LoadingStoryScreen({
    super.key,
    required this.story,
    this.storyNumber = 1,
  });

  @override
  State<LoadingStoryScreen> createState() => _LoadingStoryScreenState();
}

class _LoadingStoryScreenState extends State<LoadingStoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<String> _loadingTips = [
    "Descubriendo leyendas ancestrales...",
    "Traduciendo relatos tradicionales...",
    "Preparando la historia...",
    "Conectando con nuestras raíces..."
  ];
  late String _currentTip;

  @override
  void initState() {
    super.initState();
    _currentTip = (_loadingTips..shuffle()).first;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoryReaderScreen(
            story: widget.story,
            storyNumber: widget.storyNumber,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.story['title'] ?? 'Historia';

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/coco loco.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.auto_stories, size: 100, color: AppColors.primaryYellow),
                  ),
                ),
                const SizedBox(height: 35),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Noot',
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _currentTip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 35),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primaryYellow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}