import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/levels/screens/lesson_assembler_screen.dart';

class LoadingLevelScreen extends StatefulWidget {
  final int languageId;
  final int levelNumber;
  final int? specificLevelId;
  final String levelTitle;

  const LoadingLevelScreen({
    super.key,
    required this.languageId,
    required this.levelNumber,
    this.specificLevelId,
    required this.levelTitle,
  });

  @override
  State<LoadingLevelScreen> createState() => _LoadingLevelScreenState();
}

class _LoadingLevelScreenState extends State<LoadingLevelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _loadLevelDataAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLevelDataAndNavigate() async {
    try {
      final supabase = Supabase.instance.client;
      int targetLevelId = widget.specificLevelId ?? 0;

      if (targetLevelId == 0) {
        final levelResponse = await supabase
            .from('levels')
            .select('id')
            .eq('language_id', widget.languageId)
            .eq('level_number', widget.levelNumber)
            .maybeSingle();

        if (levelResponse != null) {
          targetLevelId = levelResponse['id'];
        }
      }

      if (targetLevelId == 0) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: No se encontró el nivel en la base de datos")),
          );
        }
        return;
      }

      // Obtener las lecciones de este nivel
      final lessonsResponse = await supabase
          .from('lessons')
          .select()
          .eq('level_id', targetLevelId)
          .order('lesson_number', ascending: true);

      List<Map<String, dynamic>> lessonsList = [];

      for (var lesson in lessonsResponse) {
        final lessonId = lesson['id'];
        final String lessonType = lesson['lesson_type'] ?? 'multiple_choice';

        List<Map<String, dynamic>> questionsList = [];

        // CORRECCIÓN: Si es introduction, consultamos las preguntas asociadas a la lección 
        // (ya que questions sí se relaciona con lesson_id según tu diagrama)
        final questionsResponse = await supabase
            .from('questions')
            .select()
            .eq('lesson_id', lessonId)
            .order('order_number', ascending: true);

        for (var question in questionsResponse) {
          final questionId = question['id'];

          final optionsResponse = await supabase
              .from('question_options')
              .select()
              .eq('question_id', questionId);

          questionsList.add({
            ...question,
            'question_options': optionsResponse,
          });
        }

        // Si es una introducción y por diseño no tiene preguntas en la BD, 
        // le pasamos las opciones basadas en la info de la lección para que no falle.
        if (questionsList.isEmpty && lessonType == 'introduction') {
          questionsList.add({
            'question_text': lesson['title'] ?? 'Palabras Nuevas',
            'question_options': [
              {'option_text': '${lesson['title']}: ${lesson['description'] ?? ''}'}
            ],
            'image_url': null,
          });
        }

        lessonsList.add({
          ...lesson,
          'lessonType': lessonType,
          'xpReward': lesson['xp_reward'] ?? 15,
          'questions': questionsList,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LessonAssemblerScreen(
              levelId: targetLevelId,
              levelTitle: widget.levelTitle,
              lessonsList: lessonsList,
              languageId: widget.languageId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cargando los datos del nivel: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar la lección: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "¡¡ Empecemos pues chavalo !!",
                    style: TextStyle(
                      fontFamily: 'Noot',
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/coco_señalando.png',
                    height: 180,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      size: 100,
                      color: AppColors.primaryYellow,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                const Text(
                  "Cargando primera clase...",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
                      minHeight: 12,
                    ),
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