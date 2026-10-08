import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nicalingo/core/services/cache_service.dart';
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

class _LoadingLevelScreenState extends State<LoadingLevelScreen>
    with SingleTickerProviderStateMixin {
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

  Future<bool> _hasInternetConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    return !connectivity.contains(ConnectivityResult.none);
  }

  String _getLevelCacheKey(int levelId) {
    return 'cached_full_level_${widget.languageId}_${widget.levelNumber}_$levelId';
  }

  Future<void> _loadLevelDataAndNavigate() async {
    final cache = await CacheService.instance;
    final hasInternet = await _hasInternetConnection();
    int targetLevelId = widget.specificLevelId ?? 0;

    // Intentar buscar ID guardado en caché si targetLevelId es 0
    final cacheIdKey = 'level_id_lookup_${widget.languageId}_${widget.levelNumber}';
    if (targetLevelId == 0) {
      final cachedId = cache.getData(cacheIdKey);
      if (cachedId != null && cachedId is int) {
        targetLevelId = cachedId;
      }
    }

    final cacheKey = _getLevelCacheKey(targetLevelId);

    // 1. MODO OFFLINE: Si no hay internet, intentar cargar desde el caché local
    if (!hasInternet) {
      final cachedData = cache.getData(cacheKey);
      if (cachedData != null && cachedData is Map) {
        final lessonsList = List<Map<String, dynamic>>.from(
          (cachedData['lessons'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        final resolvedLevelId = (cachedData['level_id'] as int?) ?? targetLevelId;

        _navigateToLesson(resolvedLevelId, lessonsList);
        return;
      } else {
        _showErrorDialog(
          "No tienes conexión a internet y este nivel aún no ha sido descargado en tu dispositivo. Conéctate una vez para jugarlo sin conexión.",
        );
        return;
      }
    }

    // 2. MODO ONLINE: Consultar Supabase y almacenar copia completa en caché
    try {
      final supabase = Supabase.instance.client;

      debugPrint(
          "🟡 INICIANDO CARGA: ID = $targetLevelId, Number = ${widget.levelNumber}, LanguageId = ${widget.languageId}");

      // Si no viene el ID específico, lo buscamos en levels
      if (targetLevelId == 0) {
        final levelResponse = await supabase
            .from('levels')
            .select('id')
            .eq('language_id', widget.languageId)
            .eq('level_number', widget.levelNumber)
            .maybeSingle();

        if (levelResponse != null) {
          targetLevelId = levelResponse['id'];
          await cache.saveData(cacheIdKey, targetLevelId);
        }
      }

      if (targetLevelId == 0) {
        throw Exception("No se encontró el nivel en la base de datos (levels).");
      }

      // Traer lecciones del nivel
      final lessonsResponse = await supabase
          .from('lessons')
          .select()
          .eq('level_id', targetLevelId);

      if (lessonsResponse.isEmpty) {
        throw Exception("La tabla 'lessons' no tiene registros con level_id = $targetLevelId.");
      }

      List<Map<String, dynamic>> lessonsList = [];

      // Traer preguntas y opciones de cada lección
      for (var lesson in lessonsResponse) {
        final lessonId = lesson['id'];
        final String lessonType =
            (lesson['lesson_type'] ?? 'multiple_choice').toString().trim();

        final questionsResponse = await supabase
            .from('questions')
            .select()
            .eq('lesson_id', lessonId);

        List<Map<String, dynamic>> questionsList = [];

        for (var question in questionsResponse) {
          final questionId = question['id'];

          final optionsResponse = await supabase
              .from('question_options')
              .select()
              .eq('question_id', questionId);

          questionsList.add({
            ...question,
            'word_translation':
                question['word_translation'] ?? lesson['description'],
            'question_options': optionsResponse,
          });
        }

        // Respaldo para lecciones de introducción
        if (questionsList.isEmpty && lessonType == 'introduction') {
          questionsList.add({
            'question_text': lesson['title'] ?? 'Palabras Nuevas',
            'question_options': [
              {
                'option_text':
                    '${lesson['title']}: ${lesson['description'] ?? ''}'
              }
            ],
            'image_url': null,
          });
        }

        lessonsList.add({
          ...lesson,
          'lessonType': lessonType,
          'lesson_type': lessonType,
          'xpReward': lesson['xp_reward'] ?? 15,
          'questions': questionsList,
        });
      }

      // Guardar nivel completo en caché local
      await cache.saveData(_getLevelCacheKey(targetLevelId), {
        'level_id': targetLevelId,
        'lessons': lessonsList,
      });

      _navigateToLesson(targetLevelId, lessonsList);
    } catch (e, stack) {
      debugPrint("🔴 ERROR CARGANDO NIVEL (INTENTANDO CACHÉ): $e");
      debugPrint("🔴 STACKTRACE: $stack");

      // Si la consulta en red falló por señal débil, buscar si existe copia local
      final cachedData = cache.getData(_getLevelCacheKey(targetLevelId));
      if (cachedData != null && cachedData is Map) {
        final lessonsList = List<Map<String, dynamic>>.from(
          (cachedData['lessons'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _navigateToLesson(targetLevelId, lessonsList);
        return;
      }

      _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
    }
  }

  void _navigateToLesson(int levelId, List<Map<String, dynamic>> lessonsList) {
    final cleanTitle = widget.levelTitle
        .replaceAll("Cargando ", "")
        .replaceAll("...", "")
        .trim();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LessonAssemblerScreen(
            levelId: levelId,
            levelTitle: cleanTitle.isNotEmpty ? cleanTitle : "Nivel",
            lessonsList: lessonsList,
            languageId: widget.languageId,
          ),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Aviso del Nivel"),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Regresar al mapa"),
          ),
        ],
      ),
    );
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryYellow),
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