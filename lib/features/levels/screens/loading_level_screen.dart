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

class _LoadingLevelScreenState extends State<LoadingLevelScreen> {
  @override
  void initState() {
    super.initState();
    _loadLevelDataAndNavigate();
  }

  Future<void> _loadLevelDataAndNavigate() async {
    try {
      final supabase = Supabase.instance.client;
      int targetLevelId = widget.specificLevelId ?? 0;

      // 1. Si no tenemos el ID específico, lo buscamos por número e idioma
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

      // 2. Obtener las lecciones de este nivel
      final lessonsResponse = await supabase
          .from('lessons')
          .select()
          .eq('level_id', targetLevelId)
          .order('lesson_number', ascending: true);

      List<Map<String, dynamic>> lessonsList = [];

      for (var lesson in lessonsResponse) {
        final lessonId = lesson['id'];

        // 3. Obtener las preguntas de cada lección
        final questionsResponse = await supabase
            .from('questions')
            .select()
            .eq('lesson_id', lessonId)
            .order('order_number', ascending: true);

        List<Map<String, dynamic>> questionsList = [];

        for (var question in questionsResponse) {
          final questionId = question['id'];

          // 4. Obtener las opciones de cada pregunta
          final optionsResponse = await supabase
              .from('question_options')
              .select()
              .eq('question_id', questionId);

          questionsList.add({
            ...question,
            'question_options': optionsResponse,
          });
        }

        lessonsList.add({
          ...lesson,
          'lessonType': lesson['lesson_type'] ?? 'multiple_choice',
          'xpReward': lesson['xp_reward'] ?? 15,
          'questions': questionsList,
        });
      }

      if (mounted) {
        // 5. Navegamos al ensamblador de lecciones enviando explícitamente el languageId
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LessonAssemblerScreen(
              levelId: targetLevelId,
              levelTitle: widget.levelTitle,
              lessonsList: lessonsList,
              languageId: widget.languageId, // <--- Aquí se inyecta el ID del idioma correctamente
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
      backgroundColor: const Color(0xFF1B2A6B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryYellow),
            const SizedBox(height: 24),
            Text(
              widget.levelTitle,
              style: const TextStyle(
                fontFamily: 'Noot',
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Preparando tu lección...",
              style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}