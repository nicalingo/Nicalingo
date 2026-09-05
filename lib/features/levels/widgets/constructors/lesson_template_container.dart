import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class LessonTemplateContainer extends StatefulWidget {
  final String lessonTitle;
  final String lessonType;
  final List<dynamic> questions;
  final int currentIndexLesson;
  final int totalLessons;
  final Function(int errorsInLesson) onLessonCompleted;

  const LessonTemplateContainer({
    super.key,
    required this.lessonTitle,
    required this.lessonType,
    required this.questions,
    required this.currentIndexLesson,
    required this.totalLessons,
    required this.onLessonCompleted,
  });

  @override
  State<LessonTemplateContainer> createState() => _LessonTemplateContainerState();
}

class _LessonTemplateContainerState extends State<LessonTemplateContainer> {
  int currentQuestionIndex = 0;
  int localErrors = 0;
  int? selectedOptionIndex;
  bool answered = false;

  List<String> availableWords = [];
  List<String> selectedWords = [];

  Map<String, dynamic> get currentQ => widget.questions[currentQuestionIndex];

  @override
  void initState() {
    super.initState();
    _initQuestionState();
  }

  @override
  void didUpdateWidget(covariant LessonTemplateContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndexLesson != widget.currentIndexLesson ||
        currentQuestionIndex >= widget.questions.length) {
      currentQuestionIndex = 0;
      localErrors = 0;
      _initQuestionState();
    }
  }

  void _initQuestionState() {
    answered = false;
    selectedOptionIndex = null;
    selectedWords.clear();

    if (widget.lessonType == 'order_phrase') {
      final List<dynamic> options = currentQ['question_options'] ?? [];
      availableWords = options.map((o) => o['option_text'].toString()).toList();
      availableWords.shuffle();
    }
  }

  void _handleAnswerSelection(bool isCorrect, int optionIndex) {
    if (answered) return;

    setState(() {
      answered = true;
      selectedOptionIndex = optionIndex;
      if (!isCorrect) {
        localErrors++;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _initQuestionState();
      });
    } else {
      widget.onLessonCompleted(localErrors);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.lessonType) {
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

  Widget _buildOptionalImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: FaIcon(FontAwesomeIcons.image, size: 40, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  // Vista de Introducción: Muestra todas las palabras de la lección juntas en una lista
  Widget _buildIntroductionView() {
    final List<dynamic> options = currentQ['question_options'] ?? [];
    final String? imageUrl = currentQ['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text(widget.lessonTitle, style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Palabras Nuevas",
                style: TextStyle(fontFamily: 'Noot', color: AppColors.primaryYellow, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildOptionalImage(imageUrl),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final fullText = options[index]['option_text'] ?? '';
                    String wordTerm = fullText;
                    String translation = '';

                    if (fullText.contains(':')) {
                      final parts = fullText.split(':');
                      wordTerm = parts[0].trim();
                      translation = parts.length > 1 ? parts[1].trim() : '';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            wordTerm,
                            style: const TextStyle(fontFamily: 'Noot', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            translation,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, color: AppColors.primaryYellow),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _nextQuestion,
                child: const Text("Continuar", style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceView() {
    final String questionText = currentQ['question_text'] ?? '';
    final String? imageUrl = currentQ['image_url'];
    final List<dynamic> options = currentQ['question_options'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text("${widget.lessonTitle} (${currentQuestionIndex + 1}/${widget.questions.length})", style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (currentQuestionIndex + 1) / widget.questions.length,
                backgroundColor: Colors.white24,
                color: AppColors.primaryYellow,
                minHeight: 10,
              ),
              const SizedBox(height: 24),
              Text(
                questionText,
                style: const TextStyle(fontFamily: 'Noot', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildOptionalImage(imageUrl),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final String optionText = option['option_text'] ?? '';
                    final bool isCorrect = option['is_correct'] ?? false;

                    Color buttonColor = const Color(0xFF1E3A8A);
                    if (answered) {
                      if (isCorrect) {
                        buttonColor = Colors.green;
                      } else if (selectedOptionIndex == index) {
                        buttonColor = Colors.red;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: answered ? null : () => _handleAnswerSelection(isCorrect, index),
                        child: Text(
                          optionText,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (answered) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _nextQuestion,
                  child: const Text("Continuar", style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderPhraseView() {
    final String questionText = currentQ['question_text'] ?? 'Ordena la frase.';
    final String? imageUrl = currentQ['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text("${widget.lessonTitle} (Armar)", style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                questionText,
                style: const TextStyle(fontFamily: 'Noot', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildOptionalImage(imageUrl),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedWords.isEmpty
                      ? [const Text("Toca las palabras abajo para ordenar", style: TextStyle(fontFamily: 'Inter', color: Colors.white54))]
                      : selectedWords.map((word) => ActionChip(
                            backgroundColor: AppColors.primaryYellow,
                            label: Text(word, style: const TextStyle(fontFamily: 'Inter', color: Colors.black87, fontWeight: FontWeight.bold)),
                            onPressed: answered ? null : () {
                              setState(() {
                                selectedWords.remove(word);
                                availableWords.add(word);
                              });
                            },
                          )).toList(),
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: availableWords.map((word) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: answered ? null : () {
                        setState(() {
                          availableWords.remove(word);
                          selectedWords.add(word);
                        });
                      },
                      child: Text(word, style: const TextStyle(fontFamily: 'Inter')),
                    )).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: selectedWords.isEmpty ? null : _nextQuestion,
                child: const Text("Comprobar y Avanzar", style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultimediaView() {
    final String questionText = currentQ['question_text'] ?? 'Escucha y selecciona';
    final String? imageUrl = currentQ['image_url'];
    final List<dynamic> options = currentQ['question_options'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text("${widget.lessonTitle} (Audio)", style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOptionalImage(imageUrl),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.volumeHigh, size: 40, color: Color(0xFF1B2A6B)),
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                questionText,
                style: const TextStyle(fontFamily: 'Noot', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final String optionText = option['option_text'] ?? '';
                    final bool isCorrect = option['is_correct'] ?? false;

                    Color buttonColor = const Color(0xFF1E3A8A);
                    if (answered) {
                      if (isCorrect) {
                        buttonColor = Colors.green;
                      } else if (selectedOptionIndex == index) {
                        buttonColor = Colors.red;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: answered ? null : () => _handleAnswerSelection(isCorrect, index),
                        child: Text(
                          optionText,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (answered) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _nextQuestion,
                  child: const Text("Continuar", style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}