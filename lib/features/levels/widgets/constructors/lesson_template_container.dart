import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Map<String, dynamic> get currentQ => widget.questions.isNotEmpty 
      ? widget.questions[currentQuestionIndex] 
      : {};

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
    availableWords.clear();

    if (widget.lessonType == 'order_phrase' && widget.questions.isNotEmpty) {
      final List<dynamic> options = (currentQ['question_options'] as List<dynamic>?) ?? [];

      String target = (currentQ['correct_phrase'] ?? '').toString().trim();

      if (target.isEmpty && options.isNotEmpty) {
        Map<String, dynamic>? foundOpt;
        for (final opt in options) {
          if (opt is Map && (opt['is_correct'] == true || opt['is_correct'] == 'true')) {
            foundOpt = Map<String, dynamic>.from(opt);
            break;
          }
        }

        foundOpt ??= (options.first is Map) ? Map<String, dynamic>.from(options.first) : null;

        if (foundOpt != null) {
          target = (foundOpt['option_text'] ?? '').toString().trim();
        }
      }

      if (target.isEmpty) {
        target = (currentQ['question_text'] ?? '').toString().trim();
      }

      if (target.isNotEmpty) {
        target = target[0].toUpperCase() + target.substring(1).toLowerCase();
      }
      correctAnswerText = target;

      if (target.contains(' ')) {
        availableWords = target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      } else {
        availableWords = target.split('').where((c) => c.isNotEmpty).toList();
      }

      if (availableWords.length > 1) {
        int attempts = 0;
        final String originalOrder = availableWords.join('');
        while (availableWords.join('') == originalOrder && attempts < 10) {
          availableWords.shuffle();
          attempts++;
        }
      }
    }
  }

  // Descuenta vida en Supabase de forma segura y comprueba si quedan vidas
  Future<void> _deductLifeOnMistake() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final remaining = await Supabase.instance.client.rpc(
        'deduct_life',
        params: {'user_uuid': user.id},
      );

      final int remainingLives = (remaining as int?) ?? 0;

      if (remainingLives <= 0 && mounted) {
        // Modal que finaliza la sesión por falta de vidas
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.redAccent, size: 28),
                SizedBox(width: 8),
                Text('¡Te quedaste sin vidas!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              'Has agotado todas tus vidas en esta lección. Espera a que se regeneren o vuelve más tarde.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx); // Cierra modal
                  Navigator.pop(context, false); // Regresa al mapa indicando no completado
                },
                child: const Text('Volver al mapa', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error descontando vida: $e');
    }
  }

  void _handleAnswerSelection(bool isCorrect, int optionIndex) {
    if (answered) return;

    final List<dynamic> options = (currentQ['question_options'] as List<dynamic>?) ?? [];
    
    Map<String, dynamic>? correctOpt;
    for (final opt in options) {
      if (opt is Map && (opt['is_correct'] == true || opt['is_correct'] == 'true')) {
        correctOpt = Map<String, dynamic>.from(opt);
        break;
      }
    }

    setState(() {
      answered = true;
      selectedOptionIndex = optionIndex;
      lastAnswerWasCorrect = isCorrect;
      correctAnswerText = correctOpt?['option_text']?.toString() ?? '';
      if (!isCorrect) {
        localErrors++;
      }
    });

    if (!isCorrect) {
      _deductLifeOnMistake();
    }
  }

  void _checkOrderPhrase() {
    if (answered || selectedWords.isEmpty) return;

    final String separator = correctAnswerText.contains(' ') ? ' ' : '';
    final String userResult = selectedWords.join(separator).trim();

    final String correctCapitalized = correctAnswerText.trim();
    final String correctLowerCase = correctAnswerText.trim().toLowerCase();

    final bool isCorrect = (userResult == correctCapitalized) || (userResult == correctLowerCase);

    setState(() {
      answered = true;
      lastAnswerWasCorrect = isCorrect;
      if (!isCorrect) {
        localErrors++;
      }
    });

    if (!isCorrect) {
      _deductLifeOnMistake();
    }
  }

  void _nextQuestion() {
    if (widget.questions.isEmpty || currentQuestionIndex >= widget.questions.length - 1) {
      widget.onLessonCompleted(localErrors);
    } else {
      setState(() {
        currentQuestionIndex++;
        _initQuestionState();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lessonType == 'introduction') {
      return _buildIntroductionView();
    }

    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B2A6B),
        body: Center(
          child: ElevatedButton(
            onPressed: () => widget.onLessonCompleted(0),
            child: const Text("Continuar"),
          ),
        ),
      );
    }

    switch (widget.lessonType) {
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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

  Widget _buildProgressBar() {
    final totalQ = widget.questions.isEmpty ? 1 : widget.questions.length;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Pregunta ${currentQuestionIndex + 1} de $totalQ",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
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
            value: (currentQuestionIndex + 1) / totalQ,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

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
            color: Colors.black.withValues(alpha: 0.25),
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
              Expanded(
                child: Text(
                  isCorrect ? "¡Excelente! Respuesta correcta" : "¡Ups! Respuesta incorrecta",
                  style: const TextStyle(
                    fontFamily: 'Noot',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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

  Widget _buildIntroductionView() {
    final List<dynamic> options = currentQ.isNotEmpty ? (currentQ['question_options'] ?? []) : [];
    final String? imageUrl = currentQ.isNotEmpty ? currentQ['image_url'] : null;

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
                child: options.isEmpty
                    ? const Center(
                        child: Text(
                          "¡Prepárate para esta lección!",
                          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
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
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    wordTerm,
                                    style: const TextStyle(
                                      fontFamily: 'Noot',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                    Color borderColor = Colors.white.withValues(alpha: 0.12);

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
                            color: Colors.black.withValues(alpha: 0.15),
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

  Widget _buildOrderPhraseView() {
    final String questionText = currentQ['question_text'] ?? 'Ordena la palabra';
    final String? imageUrl = currentQ['image_url'];

    final List<dynamic> options = (currentQ['question_options'] as List<dynamic>?) ?? [];
    String hintText = (currentQ['word_translation'] ?? currentQ['hint'] ?? '').toString().trim();
    if (hintText.isEmpty && options.isNotEmpty) {
      for (final opt in options) {
        if (opt is Map && opt['word_translation'] != null && opt['word_translation'].toString().isNotEmpty) {
          hintText = opt['word_translation'].toString().trim();
          break;
        }
      }
    }
    if (hintText.isEmpty) {
      hintText = (currentQ['description'] ?? '').toString().trim();
    }

    final int cleanLength = correctAnswerText.replaceAll(' ', '').length;
    final int targetLength = cleanLength > 0 ? cleanLength : (availableWords.isNotEmpty ? availableWords.length : 1);

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

              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Center(
                  child: selectedWords.isEmpty
                      ? Text(
                          List.generate(targetLength, (_) => "-").join(""),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white60,
                            fontSize: 32,
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(targetLength, (index) {
                                final bool hasLetter = index < selectedWords.length;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    hasLetter ? selectedWords[index] : "-",
                                    style: TextStyle(
                                      fontFamily: 'Noot',
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: hasLetter ? AppColors.primaryYellow : Colors.white30,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                ),
              ),

              const Spacer(),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hintText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        hintText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: List.generate(availableWords.length, (index) {
                            final char = availableWords[index];
                            return SizedBox(
                              width: 48,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1B2A6B),
                                  padding: EdgeInsets.zero,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: answered || selectedWords.length >= targetLength
                                    ? null
                                    : () {
                                        setState(() {
                                          final picked = availableWords.removeAt(index);
                                          selectedWords.add(picked);
                                        });
                                      },
                                child: Text(
                                  char,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),

                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 58,
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: answered || selectedWords.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        final last = selectedWords.removeLast();
                                        availableWords.add(last);
                                      });
                                    },
                              child: const Icon(Icons.backspace_rounded, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              if (!answered)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                  onPressed: selectedWords.isEmpty ? null : _checkOrderPhrase,
                  child: const Text(
                    "COMPROBAR",
                    style: TextStyle(
                      fontFamily: 'Noot',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              if (answered) _buildFeedbackBanner(),
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
                        color: Colors.black.withValues(alpha: 0.25),
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
                    Color borderColor = Colors.white.withValues(alpha: 0.12);

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
                            color: Colors.black.withValues(alpha: 0.15),
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