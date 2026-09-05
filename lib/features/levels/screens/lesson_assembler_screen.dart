import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/levels/widgets/constructors/lesson_template_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LessonAssemblerScreen extends StatefulWidget {
  final int levelId;
  final String levelTitle;
  final List<Map<String, dynamic>> lessonsList;
  final int languageId;

  const LessonAssemblerScreen({
    super.key,
    required this.levelId,
    required this.levelTitle,
    required this.lessonsList,
    this.languageId = 1,
  });

  @override
  State<LessonAssemblerScreen> createState() => _LessonAssemblerScreenState();
}

class _LessonAssemblerScreenState extends State<LessonAssemblerScreen> {
  int currentLessonIndex = 0;
  int totalErrorsCommitted = 0;
  int lessonsPassedCount = 0;
  int accumulatedXp = 0;

  bool isFinished = false;
  bool isSaving = false;

  Map<String, dynamic> get currentLesson => widget.lessonsList[currentLessonIndex];
  List<dynamic> get questions => currentLesson['questions'] ?? [];

  void _onLessonFinished({required int errorsInLesson}) {
    setState(() {
      totalErrorsCommitted += errorsInLesson;
      lessonsPassedCount++;
      accumulatedXp += (currentLesson['xpReward'] as num? ?? 15).toInt();
    });

    if (currentLessonIndex < widget.lessonsList.length - 1) {
      setState(() {
        currentLessonIndex++;
      });
    } else {
      setState(() {
        isFinished = true;
      });
      _saveFinalProgress();
    }
  }

  Future<void> _saveFinalProgress() async {
    setState(() => isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        await supabase.from('user_progress').upsert({
          'user_id': user.id,
          'level_id': widget.levelId,
          'language_id': widget.languageId,
          'is_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,level_id');
      }
    } catch (e) {
      debugPrint('Error guardando progreso en Supabase: $e');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return _buildResultScreen();
    }

    if (questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onLessonFinished(errorsInLesson: 0);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
      );
    }

    String lessonType = currentLesson['lessonType'] ?? 'multiple_choice';

    return LessonTemplateContainer(
      lessonTitle: currentLesson['title'] ?? widget.levelTitle,
      lessonType: lessonType,
      questions: questions,
      currentIndexLesson: currentLessonIndex,
      totalLessons: widget.lessonsList.length,
      onLessonCompleted: (errors) {
        _onLessonFinished(errorsInLesson: errors);
      },
    );
  }

  Widget _buildResultScreen() {
    final bool isPerfect = totalErrorsCommitted == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.trophy, size: 72, color: AppColors.primaryYellow),
                  const SizedBox(height: 24),
                  const Text(
                    "¡NIVEL COMPLETADO!",
                    style: TextStyle(
                      fontFamily: 'Noot',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Has completado ${widget.levelTitle}",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Fila de métricas adaptables sin overflow de píxeles
                  Row(
                    children: [
                      Expanded(
                        child: _metricBadge(
                          icon: FontAwesomeIcons.star,
                          label: "+$accumulatedXp XP",
                          color: AppColors.primaryYellow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBadge(
                          icon: isPerfect ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
                          label: isPerfect
                              ? "0 Errores"
                              : "$totalErrorsCommitted ${totalErrorsCommitted == 1 ? 'Error' : 'Errores'}",
                          color: isPerfect ? const Color(0xFF4ADE80) : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryYellow,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () {
                              Navigator.pop(context, true);
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black87,
                              ),
                            )
                          : const Text(
                              "CONTINUAR AL MAPA",
                              style: TextStyle(
                                fontFamily: 'Noot',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBadge({required dynamic icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}