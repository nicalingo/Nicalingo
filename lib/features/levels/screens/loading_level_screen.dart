import 'package:flutter/material.dart';
import 'package:nicalingo/features/levels/screens/lesson_assembler_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoadingLevelScreen extends StatefulWidget {
  final int languageId;
  final int levelNumber;
  final int? specificLevelId;
  final String levelTitle;

  const LoadingLevelScreen({
    super.key,
    this.languageId = 1,
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
    _loadAllLessonsForLevelAndNavigate();
  }

  Future<void> _loadAllLessonsForLevelAndNavigate() async {
    try {
      final supabase = Supabase.instance.client;
      int realLevelId;

      if (widget.specificLevelId != null) {
        realLevelId = widget.specificLevelId!;
      } else {
        final levelResponse = await supabase
            .from('levels')
            .select('id')
            .eq('language_id', widget.languageId)
            .eq('level_number', widget.levelNumber)
            .maybeSingle();

        if (levelResponse == null) {
          throw Exception('El Nivel ${widget.levelNumber} no está registrado.');
        }
        realLevelId = levelResponse['id'];
      }

      final lessonsResponse = await supabase
          .from('lessons')
          .select('id, xp_reward, title, lesson_type, lesson_number')
          .eq('level_id', realLevelId)
          .order('lesson_number', ascending: true);

      final List<dynamic> lessons = lessonsResponse;

      if (lessons.isEmpty) {
        throw Exception('Este nivel aún no tiene lecciones creadas.');
      }

      List<Map<String, dynamic>> enrichedLessons = [];

      for (var lesson in lessons) {
        final int lessonId = lesson['id'];
        
        final questionsResponse = await supabase
            .from('questions')
            .select('id, question_text, question_options(id, option_text, is_correct)')
            .eq('lesson_id', lessonId);

        enrichedLessons.add({
          'lessonId': lessonId,
          'title': lesson['title'] ?? widget.levelTitle,
          'lessonType': lesson['lesson_type'] ?? 'multiple_choice',
          'xpReward': lesson['xp_reward'] ?? 15,
          'questions': questionsResponse,
        });
      }

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LessonAssemblerScreen(
              levelId: realLevelId,
              levelTitle: widget.levelTitle,
              lessonsList: enrichedLessons,
              currentLessonIndex: 0,
              accumulatedXp: 0,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el nivel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFFFEB3B);
    const Color containerColor = Color(0xFF1E3A8A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "¡¡ Empecemos pues\nchavalo !!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Image.asset(
                      'assets/images/coco loco.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Text(
                          widget.levelTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              backgroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}