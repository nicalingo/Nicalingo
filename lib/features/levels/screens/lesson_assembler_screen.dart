import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LessonAssemblerScreen extends StatefulWidget {
  final int levelId;
  final String levelTitle;
  final List<Map<String, dynamic>> lessonsList;
  final int currentLessonIndex;
  final int accumulatedXp;

  const LessonAssemblerScreen({
    super.key,
    required this.levelId,
    required this.levelTitle,
    required this.lessonsList,
    required this.currentLessonIndex,
    required this.accumulatedXp,
  });

  @override
  State<LessonAssemblerScreen> createState() => _LessonAssemblerScreenState();
}

class _LessonAssemblerScreenState extends State<LessonAssemblerScreen> {
  int currentQuestionIndex = 0;
  bool isFinished = false;
  bool isSaving = false;

  Map<String, dynamic> get currentLesson => widget.lessonsList[widget.currentLessonIndex];
  List<dynamic> get questions => currentLesson['questions'] ?? [];

  void _nextStep() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _handleLessonCompletion();
    }
  }

  void _handleLessonCompletion() {
    int lessonXp = (currentLesson['xpReward'] as num? ?? 15).toInt();
    int newAccumulatedXp = widget.accumulatedXp + lessonXp;
    int nextLessonIndex = widget.currentLessonIndex + 1;

    if (nextLessonIndex < widget.lessonsList.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LessonAssemblerScreen(
            levelId: widget.levelId,
            levelTitle: widget.levelTitle,
            lessonsList: widget.lessonsList,
            currentLessonIndex: nextLessonIndex,
            accumulatedXp: newAccumulatedXp,
          ),
        ),
      );
    } else {
      setState(() {
        isFinished = true;
      });
      _saveFinalProgress(newAccumulatedXp);
    }
  }

  Future<void> _saveFinalProgress(int finalXp) async {
    setState(() => isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final existingProgress = await supabase
            .from('user_progress')
            .select('xp')
            .eq('user_id', user.id)
            .maybeSingle();

        int currentXp = existingProgress?['xp'] ?? 0;
        int totalNewXp = currentXp + finalXp;

        await supabase.from('user_progress').upsert({
          'user_id': user.id,
          'xp': totalNewXp,
          'last_activity': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error guardando progreso: $e');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return _buildFeedbackScreen();
    }

    if (questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleLessonCompletion());
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
      );
    }

    String lessonType = currentLesson['lessonType'] ?? 'multiple_choice';

    switch (lessonType) {
      case 'introduction':
        return _buildIntroductionView();
      case 'multiple_choice':
        return _buildMultipleChoiceView();
      case 'order_phrase':
        return _buildOrderPhraseView();
      case 'multimedia':
        return _buildMultimediaView();
      default:
        return _buildMultipleChoiceView();
    }
  }

  Widget _buildFeedbackScreen() {
    int totalXpEarned = widget.accumulatedXp + (currentLesson['xpReward'] as num? ?? 15).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32),
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
                    "¡Nivel Completado!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Has completado todas las lecciones de\n${widget.levelTitle}",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.star, color: AppColors.primaryYellow, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "+$totalXpEarned XP Ganados",
                          style: const TextStyle(
                            color: AppColors.primaryYellow,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
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
                      ),
                      onPressed: isSaving
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.black87)
                          : const Text(
                              "Continuar al Mapa",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildIntroductionView() {
    final currentQ = questions[currentQuestionIndex];
    final String text = currentQ['question_text'] ?? 'Lee atentamente.';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentLesson['title']),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.bookOpenReader, size: 64, color: Color(0xFF1E3A8A)),
            const SizedBox(height: 32),
            Text(
              text,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _nextStep,
              child: const Text("¡Entendido, continuar!", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceView() {
    final currentQ = questions[currentQuestionIndex];
    final String questionText = currentQ['question_text'] ?? '';
    final List<dynamic> options = currentQ['question_options'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text("${currentLesson['title']} (${currentQuestionIndex + 1}/${questions.length})"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (currentQuestionIndex + 1) / questions.length,
              backgroundColor: Colors.grey[300],
              color: AppColors.primaryYellow,
              minHeight: 10,
            ),
            const SizedBox(height: 35),
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final String optionText = option['option_text'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _nextStep,
                      child: Text(
                        optionText,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPhraseView() {
    final currentQ = questions[currentQuestionIndex];
    final String questionText = currentQ['question_text'] ?? 'Ordena la frase.';

    return Scaffold(
      appBar: AppBar(
        title: Text("${currentLesson['title']} (Armar)"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              "[ Área interactiva para ordenar frases ]",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _nextStep,
              child: const Text("Comprobar y Avanzar", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultimediaView() {
    final currentQ = questions[currentQuestionIndex];
    final String questionText = currentQ['question_text'] ?? 'Multimedia';

    return Scaffold(
      appBar: AppBar(
        title: Text("${currentLesson['title']} (Audio/Video)"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FaIcon(FontAwesomeIcons.circlePlay, size: 64, color: Color(0xFF1E3A8A)),
            const SizedBox(height: 24),
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _nextStep,
              child: const Text("Continuar", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}