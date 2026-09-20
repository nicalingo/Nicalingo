import 'dart:async';
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
  int accumulatedXp = 0;

  // Errores y XP de la lección individual recién completada
  int lastLessonErrors = 0;
  int lastLessonXp = 0;

  // Historial de errores por lección para colorear la barra
  final List<int> lessonErrorsHistory = [];

  bool isLevelFinished = false;
  bool isShowingLessonSummary = false; // Control de pantalla intermedia lección a lección
  bool isSaving = false;

  Map<String, dynamic> get currentLesson =>
      widget.lessonsList.isNotEmpty &&
              currentLessonIndex < widget.lessonsList.length
          ? widget.lessonsList[currentLessonIndex]
          : {};

  List<dynamic> get questions =>
      (currentLesson['questions'] as List<dynamic>?) ?? [];

  void _onLessonFinished({required int errorsInLesson}) {
    final int xpEarned = (currentLesson['xpReward'] as num? ??
            currentLesson['xp_reward'] as num? ??
            15)
        .toInt();

    setState(() {
      lastLessonErrors = errorsInLesson;
      lastLessonXp = xpEarned;
      lessonErrorsHistory.add(errorsInLesson);
      totalErrorsCommitted += errorsInLesson;
      accumulatedXp += xpEarned;

      // Mostramos la pantalla de felicitaciones de la lección terminada
      isShowingLessonSummary = true;
    });
  }

  void _goToNextLesson() {
    if (currentLessonIndex < widget.lessonsList.length - 1) {
      setState(() {
        currentLessonIndex++;
        isShowingLessonSummary = false;
      });
    } else {
      // Llegó al final del conjunto de lecciones del nivel
      setState(() {
        isShowingLessonSummary = false;
        isLevelFinished = true;
      });
      _saveFinalProgress();
    }
  }

  Future<void> _saveFinalProgress() async {
    setState(() => isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("No hay usuario autenticado en la sesión actual.");
      }

      final int targetLevelId = widget.levelId;
      final int targetLanguageId = widget.languageId;
      debugPrint("🚀 Guardando progreso: user_id=${user.id}, language_id=$targetLanguageId, level_id=$targetLevelId");

      final response = await supabase.from('user_progress').upsert(
        {
          'user_id': user.id,
          'language_id': targetLanguageId,
          'level_id': targetLevelId,
          'current_level_id': targetLevelId,
          'is_completed': true,
          'last_activity': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id, language_id',
      ).select();

      debugPrint("✅ RESPUESTA SUPABASE user_progress: $response");

      // Disparar cálculo y persistencia de la racha diaria
      try {
        final newStreak = await supabase.rpc(
          'update_user_streak',
          params: {'user_uuid': user.id},
        );
        debugPrint("🔥 Racha sincronizada correctamente: $newStreak");
      } catch (streakError) {
        debugPrint("⚠️ Aviso actualizando racha: $streakError");
      }
    } catch (e, stack) {
      debugPrint("❌ ERROR GUARDANDO PROGRESO: $e");
      debugPrint("❌ STACK: $stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando progreso: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  String _resolveLessonType(Map<String, dynamic> lesson) {
    final rawType =
        (lesson['lessonType'] ?? lesson['lesson_type'] ?? 'multiple_choice')
            .toString()
            .trim()
            .toLowerCase();

    switch (rawType) {
      // Tipos para fonética y reconocimiento de voz (Lección 1 Figma)
      case 'pronunciation':
      case 'fonetica':
      case 'speech':
      case 'habla':
        return 'pronunciation';
      // Tipos para completar la frase (Lección 2 Figma)
      case 'fill_blank':
      case 'completa_frase':
      case 'completar_frase':
      case 'complete_phrase':
        return 'fill_blank';
      case 'order_phrase':
      case 'order_word':
      case 'order_words':
      case 'ordenar_palabra':
      case 'ordenar_frase':
        return 'order_phrase';
      case 'introduction':
      case 'introduccion':
        return 'introduction';
      case 'multimedia':
      case 'audio':
        return 'multimedia';
      case 'multiple_choice':
      case 'seleccion_multiple':
      default:
        return 'multiple_choice';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla final cuando termina todo el nivel
    if (isLevelFinished) {
      return _buildFinalLevelScreen();
    }

    // 2. Pantalla intermedia al completar cada lección individual
    if (isShowingLessonSummary) {
      return _buildLessonSummaryScreen();
    }

    // 3. Fallback de preguntas vacías
    if (questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onLessonFinished(errorsInLesson: 0);
      });
      return const Scaffold(
        backgroundColor: Color(0xFF1B2A6B),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryYellow),
        ),
      );
    }

    final String resolvedLessonType = _resolveLessonType(currentLesson);

    // 4. Contenedor de la lección activa
    return LessonTemplateContainer(
      key: ValueKey("lesson_${widget.levelId}_$currentLessonIndex"),
      lessonTitle: currentLesson['title'] ?? widget.levelTitle,
      lessonType: resolvedLessonType,
      questions: questions,
      currentIndexLesson: currentLessonIndex,
      totalLessons: widget.lessonsList.length,
      lessonErrorsHistory: lessonErrorsHistory,
      onLessonCompleted: (errors) {
        _onLessonFinished(errorsInLesson: errors);
      },
    );
  }

  /// Vista intermedia: Aparece al terminar cada lección individual
  Widget _buildLessonSummaryScreen() {
    final bool isLastLesson = currentLessonIndex >= widget.lessonsList.length - 1;

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
                  const FaIcon(
                    FontAwesomeIcons.circleCheck,
                    size: 68,
                    color: Color(0xFF4ADE80),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "¡LECCIÓN ${currentLessonIndex + 1} COMPLETADA!",
                    style: const TextStyle(
                      fontFamily: 'Noot',
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentLesson['title'] ?? widget.levelTitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _metricBadge(
                          icon: FontAwesomeIcons.star,
                          label: "+$lastLessonXp XP",
                          color: AppColors.primaryYellow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBadge(
                          icon: lastLessonErrors == 0
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circleXmark,
                          label: lastLessonErrors == 0
                              ? "0 Errores"
                              : "$lastLessonErrors ${lastLessonErrors == 1 ? 'Error' : 'Errores'}",
                          color: lastLessonErrors == 0
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
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
                      onPressed: _goToNextLesson,
                      child: Text(
                        isLastLesson ? "FINALIZAR NIVEL" : "SIGUIENTE LECCIÓN",
                        style: const TextStyle(
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

  /// Vista final: Aparece únicamente cuando se completaron todas las lecciones del nivel
  Widget _buildFinalLevelScreen() {
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
                  const FaIcon(
                    FontAwesomeIcons.trophy,
                    size: 72,
                    color: AppColors.primaryYellow,
                  ),
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
                    "Has completado todas las lecciones de ${widget.levelTitle}",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                          icon: isPerfect
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circleXmark,
                          label: isPerfect
                              ? "0 Errores"
                              : "$totalErrorsCommitted ${totalErrorsCommitted == 1 ? 'Error' : 'Errores'}",
                          color: isPerfect
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFFF5252),
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

  Widget _metricBadge({
    required dynamic icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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