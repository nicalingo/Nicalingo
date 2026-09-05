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
  bool lastAnswerWasCorrect = false;
  String correctAnswerText = '';

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
    lastAnswerWasCorrect = false;
    correctAnswerText = '';
    selectedWords.clear();

    if (widget.lessonType == 'order_phrase') {
      final List<dynamic> options = currentQ['question_options'] ?? [];
      availableWords = options.map((o) => o['option_text'].toString()).toList();
      availableWords.shuffle();
    }
  }

  void _handleAnswerSelection(bool isCorrect, int optionIndex) {
    if (answered) return;

    final List<dynamic> options = currentQ['question_options'] ?? [];
    final correctOpt = options.firstWhere(
      (o) => o['is_correct'] == true,
      orElse: () => null,
    );

    setState(() {
      answered = true;
      selectedOptionIndex = optionIndex;
      lastAnswerWasCorrect = isCorrect;
      correctAnswerText = correctOpt != null ? correctOpt['option_text'] ?? '' : '';
      if (!isCorrect) {
        localErrors++;
      }
    });
  }

  void _checkOrderPhrase() {
    if (answered) return;

    final List<dynamic> options = currentQ['question_options'] ?? [];
    final String expectedPhrase = currentQ['correct_phrase'] ??
        options.map((o) => o['option_text'].toString()).join(' ');

    final String userPhrase = selectedWords.join(' ');
    final bool isCorrect = userPhrase.trim().toLowerCase() == expectedPhrase.trim().toLowerCase();

    setState(() {
      answered = true;
      lastAnswerWasCorrect = isCorrect;
      correctAnswerText = expectedPhrase;
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
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
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

  // Barra de progreso interactiva
  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Pregunta ${currentQuestionIndex + 1} de ${widget.questions.length}",
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  localErrors == 0 ? "Perfecto" : "$localErrors ${localErrors == 1 ? 'error' : 'errores'}",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: localErrors == 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / widget.questions.length,
            backgroundColor: Colors.white.withAlpha(40),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  // Panel inferior animado de feedback
  Widget _buildFeedbackBanner() {
    final isCorrect = lastAnswerWasCorrect;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFF1E7E34) : const Color(0xFFC82333),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? "¡Excelente! Respuesta correcta" : "¡Ups! Respuesta incorrecta",
                style: const TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (!isCorrect && correctAnswerText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Respuesta correcta: $correctAnswerText",
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _nextQuestion,
            child: const Text(
              "Continuar",
              style: TextStyle(fontFamily: 'Noot', fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Vista de Introducción
  Widget _buildIntroductionView() {
    final List<dynamic> options = currentQ['question_options'] ?? [];
    final String? imageUrl = currentQ['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text(widget.lessonTitle, style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Palabras Nuevas",
                style: TextStyle(
                  fontFamily: 'Noot',
                  color: AppColors.primaryYellow,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildOptionalImage(imageUrl),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
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
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withAlpha(30)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            wordTerm,
                            style: const TextStyle(
                              fontFamily: 'Noot',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            translation,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryYellow,
                            ),
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
                  elevation: 2,
                ),
                onPressed: _nextQuestion,
                child: const Text(
                  "Comenzar Lección",
                  style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Vista de Opción Múltiple
  Widget _buildMultipleChoiceView() {
    final String questionText = currentQ['question_text'] ?? '';
    final String? imageUrl = currentQ['image_url'];
    final List<dynamic> options = currentQ['question_options'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text(widget.lessonTitle, style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 20),
              Text(
                questionText,
                style: const TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _buildOptionalImage(imageUrl),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final String optionText = option['option_text'] ?? '';
                    final bool isCorrect = option['is_correct'] ?? false;

                    Color buttonColor = const Color(0xFF1E3A8A);
                    Color borderColor = Colors.white.withAlpha(30);

                    if (answered) {
                      if (isCorrect) {
                        buttonColor = const Color(0xFF28A745);
                        borderColor = Colors.greenAccent;
                      } else if (selectedOptionIndex == index) {
                        buttonColor = const Color(0xFFDC3545);
                        borderColor = Colors.redAccent;
                      }
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor, width: 1.5),
                          ),
                          elevation: 0,
                        ),
                        onPressed: answered ? null : () => _handleAnswerSelection(isCorrect, index),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                optionText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (answered && isCorrect)
                              const Icon(Icons.check_circle, color: Colors.white, size: 22),
                            if (answered && !isCorrect && selectedOptionIndex == index)
                              const Icon(Icons.cancel, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (answered) _buildFeedbackBanner(),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Vista de Ordenar Frase
  Widget _buildOrderPhraseView() {
    final String questionText = currentQ['question_text'] ?? 'Ordena la frase.';
    final String? imageUrl = currentQ['image_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      appBar: AppBar(
        title: Text("${widget.lessonTitle} (Armar)", style: const TextStyle(fontFamily: 'Noot')),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 16),
              Text(
                questionText,
                style: const TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildOptionalImage(imageUrl),
              Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 85),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white30),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedWords.isEmpty
                      ? [
                          const Text(
                            "Toca las palabras de abajo para formar la frase",
                            style: TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 14),
                          )
                        ]
                      : selectedWords
                          .map(
                            (word) => ActionChip(
                              backgroundColor: AppColors.primaryYellow,
                              label: Text(
                                word,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: answered
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedWords.remove(word);
                                        availableWords.add(word);
                                      });
                                    },
                            ),
                          )
                          .toList(),
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: availableWords
                    .map(
                      (word) => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: answered
                          ? null
                          : () {
                              setState(() {
                                availableWords.remove(word);
                                selectedWords.add(word);
                              });
                            },
                        child: Text(word, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (!answered)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: selectedWords.isEmpty ? null : _checkOrderPhrase,
                  child: const Text(
                    "Comprobar",
                    style: TextStyle(fontFamily: 'Noot', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              if (answered) _buildFeedbackBanner(),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Vista Multimedia / Audio
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
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 16),
              _buildOptionalImage(imageUrl),
              Center(
                child: Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.volumeHigh, size: 36, color: Color(0xFF1B2A6B)),
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                questionText,
                style: const TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final String optionText = option['option_text'] ?? '';
                    final bool isCorrect = option['is_correct'] ?? false;

                    Color buttonColor = const Color(0xFF1E3A8A);
                    Color borderColor = Colors.white.withAlpha(30);

                    if (answered) {
                      if (isCorrect) {
                        buttonColor = const Color(0xFF28A745);
                        borderColor = Colors.greenAccent;
                      } else if (selectedOptionIndex == index) {
                        buttonColor = const Color(0xFFDC3545);
                        borderColor = Colors.redAccent;
                      }
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor, width: 1.5),
                          ),
                          elevation: 0,
                        ),
                        onPressed: answered ? null : () => _handleAnswerSelection(isCorrect, index),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                optionText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (answered && isCorrect)
                              const Icon(Icons.check_circle, color: Colors.white, size: 22),
                            if (answered && !isCorrect && selectedOptionIndex == index)
                              const Icon(Icons.cancel, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (answered) _buildFeedbackBanner(),
            ],
          ),
        ),
      ),
    );
  }
}