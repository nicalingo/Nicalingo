import 'dart:async';
import 'dart:math';
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

  int lastLessonErrors = 0;
  int lastLessonXp = 0;

  final List<int> lessonErrorsHistory = [];

  bool isLevelFinished = false;
  bool isShowingLessonSummary = false;
  bool isSaving = false;

  // Variables para control de tiempo y XP histórico
  late DateTime _levelStartTime;
  Duration _levelDuration = Duration.zero;
  int _previousMaxXp = 0;
  int _newFinalXpToAward = 0;

  final Random _random = Random();
  String _currentFeedbackMessage = "";

  final List<String> _successMessages = [
    "¡Excelente trabajo! Lo hiciste perfecto.",
    "¡Vas por buen camino, seguí así!",
    "¡Sos un crack! Muy bien hecho.",
    "¡Machete estate en tu vaina! Lección dominada.",
    "¡Qué bárbaro! Cero errores."
  ];

  final List<String> _encouragingMessages = [
    "¡No te ahueves! A la próxima sale mejor.",
    "Los errores te hacen más fuerte. ¡Dale otra vez!",
    "¡Casi casi! Sigue practicando.",
    "Un pequeño tropezón, pero vas avanzando.",
    "¡Tranquilo! De los errores se aprende."
  ];

  Map<String, dynamic> get currentLesson =>
      widget.lessonsList.isNotEmpty &&
              currentLessonIndex < widget.lessonsList.length
          ? widget.lessonsList[currentLessonIndex]
          : {};

  List<dynamic> get questions =>
      (currentLesson['questions'] as List<dynamic>?) ?? [];

  @override
  void initState() {
    super.initState();
    _levelStartTime = DateTime.now();
    _fetchPreviousProgress();
  }

  // Traemos el récord anterior para no duplicar XP
  Future<void> _fetchPreviousProgress() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('user_progress')
          .select('earned_xp')
          .eq('user_id', user.id)
          .eq('language_id', widget.languageId)
          .eq('level_id', widget.levelId)
          .maybeSingle();

      if (response != null && response['earned_xp'] != null) {
        if (mounted) {
          setState(() {
            _previousMaxXp = (response['earned_xp'] as num).toInt();
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Aviso: No se encontró XP previo o falta la columna: $e");
    }
  }

  void _onLessonFinished({required int errorsInLesson}) {
    int xpEarned = (currentLesson['xpReward'] as num? ??
            currentLesson['xp_reward'] as num? ??
            15)
        .toInt();

    if (errorsInLesson > 0) {
      xpEarned = 0;
      _currentFeedbackMessage =
          _encouragingMessages[_random.nextInt(_encouragingMessages.length)];
    } else {
      _currentFeedbackMessage =
          _successMessages[_random.nextInt(_successMessages.length)];
    }

    setState(() {
      lastLessonErrors = errorsInLesson;
      lastLessonXp = xpEarned;
      lessonErrorsHistory.add(errorsInLesson);
      totalErrorsCommitted += errorsInLesson;
      accumulatedXp += xpEarned;

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
      _levelDuration = DateTime.now().difference(_levelStartTime);
      
      // Calculamos solo el XP que falta por reclamar
      int difference = accumulatedXp - _previousMaxXp;
      _newFinalXpToAward = difference > 0 ? difference : 0;

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

      //  CORREGIDO: Se añade order y limit(1) para evitar el error 406 de múltiples filas
      final existingProgress = await supabase
          .from('user_progress')
          .select('current_level_id')
          .eq('user_id', user.id)
          .eq('language_id', targetLanguageId)
          .order('current_level_id', ascending: false)
          .limit(1)
          .maybeSingle();

      int highestLevelId = targetLevelId;
      if (existingProgress != null &&
          existingProgress['current_level_id'] != null) {
        final currentHighest = existingProgress['current_level_id'] as int;
        if (currentHighest > targetLevelId) {
          highestLevelId = currentHighest;
        }
      }

      await supabase.from('user_progress').upsert(
        {
          'user_id': user.id,
          'language_id': targetLanguageId,
          'level_id': targetLevelId,
          'current_level_id': highestLevelId,
          'earned_xp': max(_previousMaxXp, accumulatedXp), // Guarda el mayor puntaje logrado
          'is_completed': true,
          'last_activity': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        // Mantiene un registro individual por nivel
        onConflict: 'user_id, language_id, level_id',
      ).select();

      try {
        await supabase.rpc('update_user_streak', params: {'user_uuid': user.id});
      } catch (streakError) {
        debugPrint("⚠️ Aviso actualizando racha: $streakError");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando progreso: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return "${duration.inHours}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  String _resolveLessonType(Map<String, dynamic> lesson) {
    final rawType =
        (lesson['lessonType'] ?? lesson['lesson_type'] ?? 'multiple_choice')
            .toString()
            .trim()
            .toLowerCase();

    switch (rawType) {
      case 'pronunciation':
      case 'fonetica':
      case 'speech':
      case 'habla':
        return 'pronunciation';
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
    if (isLevelFinished) {
      return _buildFinalLevelScreen();
    }

    if (isShowingLessonSummary) {
      return _buildLessonSummaryScreen();
    }

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

    return LessonTemplateContainer(
      key: ValueKey("lesson_${widget.levelId}_$currentLessonIndex"),
      lessonTitle: currentLesson['title'] ?? widget.levelTitle,
      lessonType: _resolveLessonType(currentLesson),
      questions: questions,
      currentIndexLesson: currentLessonIndex,
      totalLessons: widget.lessonsList.length,
      lessonErrorsHistory: lessonErrorsHistory,
      onLessonCompleted: (errors) {
        _onLessonFinished(errorsInLesson: errors);
      },
    );
  }

  Widget _buildLessonSummaryScreen() {
    final bool isLastLesson =
        currentLessonIndex >= widget.lessonsList.length - 1;
    final bool isPerfect = lastLessonErrors == 0;
    
    final String imagePath = isPerfect 
        ? 'assets/images/coco_feliz.png' 
        : 'assets/images/coco_ups.png';

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
                  Image.asset(
                    imagePath,
                    height: 140,
                    errorBuilder: (context, error, stackTrace) => FaIcon(
                      isPerfect ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleExclamation,
                      size: 80,
                      color: isPerfect ? const Color(0xFF4ADE80) : const Color(0xFFFF5252),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isPerfect ? "¡LECCIÓN COMPLETADA!" : "¡LECCIÓN FINALIZADA!",
                    style: TextStyle(
                      fontFamily: 'Noot',
                      color: isPerfect ? const Color(0xFF4ADE80) : AppColors.primaryYellow,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentFeedbackMessage,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                          icon: isPerfect
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circleXmark,
                          label: isPerfect
                              ? "0 Errores"
                              : "$lastLessonErrors Errores",
                          color: isPerfect
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

  Widget _buildFinalLevelScreen() {
    String finalImagePath;
    String titleText;
    String customMessage;
    Color titleColor;

    if (totalErrorsCommitted == 0) {
      finalImagePath = 'assets/images/coco_espada.png';
      titleText = "¡CLASE PERFECTA!";
      titleColor = AppColors.primaryYellow;
      customMessage = _levelDuration.inMinutes <= widget.lessonsList.length
          ? "¡Impecable y veloz! Eres una leyenda completando niveles."
          : "¡Sin un solo error! Tienes un dominio absoluto de esta lección.";
    } else if (totalErrorsCommitted <= widget.lessonsList.length) {
      finalImagePath = 'assets/images/coco_feliz.png';
      titleText = "¡NIVEL COMPLETADO!";
      titleColor = const Color(0xFF4ADE80);
      customMessage = "¡Muy buen trabajo! Completaste el nivel de manera satisfactoria, sigue así.";
    } else {
      finalImagePath = 'assets/images/coco_ups.png';
      titleText = "¡NIVEL FINALIZADO!";
      titleColor = const Color(0xFFFF5252);
      customMessage = "Te costó un poco, pero no te rindas. ¡Repite el nivel para mejorar tu récord!";
    }

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
                  Image.asset(
                    finalImagePath,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) => FaIcon(
                      FontAwesomeIcons.trophy,
                      size: 80,
                      color: AppColors.primaryYellow,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    titleText,
                    style: TextStyle(
                      fontFamily: 'Noot',
                      color: titleColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    customMessage,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _metricBadge(
                          icon: FontAwesomeIcons.star,
                          // Muestra únicamente el XP que realmente le falta sumar a su cuenta
                          label: "+$_newFinalXpToAward XP",
                          color: AppColors.primaryYellow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBadge(
                          icon: totalErrorsCommitted == 0
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circleXmark,
                          label: totalErrorsCommitted == 0
                              ? "Perfecto"
                              : "$totalErrorsCommitted Err",
                          color: totalErrorsCommitted == 0
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _metricBadge(
                    icon: FontAwesomeIcons.stopwatch,
                    label: "Tiempo: ${_formatDuration(_levelDuration)}",
                    color: const Color(0xFF38BDF8),
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