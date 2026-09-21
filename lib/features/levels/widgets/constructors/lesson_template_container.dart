import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nicalingo/core/services/audio_recorder_service.dart';
import 'package:nicalingo/core/services/phonetic_matcher_service.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LessonTemplateContainer extends StatefulWidget {
  final String lessonTitle;
  final String lessonType;
  final List<dynamic> questions;
  final int currentIndexLesson;
  final int totalLessons;
  final List<int> lessonErrorsHistory;
  final Function(int errorsInLesson) onLessonCompleted;

  const LessonTemplateContainer({
    super.key,
    required this.lessonTitle,
    required this.lessonType,
    required this.questions,
    required this.currentIndexLesson,
    required this.totalLessons,
    this.lessonErrorsHistory = const [],
    required this.onLessonCompleted,
  });

  @override
  State<LessonTemplateContainer> createState() => _LessonTemplateContainerState();
}

class _LessonTemplateContainerState extends State<LessonTemplateContainer> {
  int currentQuestionIndex = 0;
  int localErrors = 0;
  int currentLives = 5;
  int? selectedOptionIndex;
  bool answered = false;
  bool lastAnswerWasCorrect = false;
  String correctAnswerText = '';

  List<String> availableWords = [];
  List<String> selectedWords = [];

  // Módulos de audio multiplataforma
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isRecordingAudio = false;
  bool isEvaluatingAudio = false;
  bool isPlayingNativeAudio = false;
  Uint8List? recordedUserBytes;

  Map<String, dynamic> get currentQ => widget.questions.isNotEmpty
      ? widget.questions[currentQuestionIndex]
      : {};

  @override
  void initState() {
    super.initState();
    _fetchUserLives();
    _initQuestionState();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
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

  Future<void> _fetchUserLives() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('user_progress')
          .select('lives')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['lives'] != null && mounted) {
        setState(() {
          currentLives = (data['lives'] as num).toInt();
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo vidas: $e');
    }
  }

  void _initQuestionState() {
    answered = false;
    selectedOptionIndex = null;
    lastAnswerWasCorrect = false;
    correctAnswerText = '';
    selectedWords.clear();
    availableWords.clear();
    isRecordingAudio = false;
    isEvaluatingAudio = false;
    isPlayingNativeAudio = false;
    recordedUserBytes = null;

    if (widget.lessonType == 'order_phrase' && widget.questions.isNotEmpty) {
      final List<dynamic> options =
          (currentQ['question_options'] as List<dynamic>?) ?? [];

      String target = (currentQ['correct_phrase'] ?? '').toString().trim();

      if (target.isEmpty && options.isNotEmpty) {
        Map<String, dynamic>? foundOpt;
        for (final opt in options) {
          if (opt is Map &&
              (opt['is_correct'] == true || opt['is_correct'] == 'true')) {
            foundOpt = Map<String, dynamic>.from(opt);
            break;
          }
        }

        foundOpt ??=
            (options.first is Map) ? Map<String, dynamic>.from(options.first) : null;

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
        availableWords =
            target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
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

  Future<void> _deductLifeOnMistake() async {
    // FIX 3: Actualización optimista de UI para respuesta rápida visual
    if (mounted) {
      setState(() {
        if (currentLives > 0) {
          currentLives--;
        }
      });
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final remaining = await Supabase.instance.client.rpc(
        'deduct_life',
        params: {'user_uuid': user.id},
      );

      final int dbRemainingLives = (remaining as int?) ?? currentLives;

      // Sincronizar por si la base de datos devuelve algo distinto al cálculo local
      if (mounted && currentLives != dbRemainingLives) {
        setState(() {
          currentLives = dbRemainingLives;
        });
      }

      if (currentLives <= 0 && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.redAccent, size: 28),
                SizedBox(width: 8),
                Text('¡Te quedaste sin vidas!',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context, false);
                },
                child: const Text('Volver al mapa',
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold)),
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

    final List<dynamic> options =
        (currentQ['question_options'] as List<dynamic>?) ?? [];

    Map<String, dynamic>? correctOpt;
    for (final opt in options) {
      if (opt is Map &&
          (opt['is_correct'] == true || opt['is_correct'] == 'true')) {
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

    final bool isCorrect =
        (userResult == correctCapitalized) || (userResult == correctLowerCase);

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

  Future<void> _playNativeAudio(String url) async {
    if (url.isEmpty || isPlayingNativeAudio) return;
    try {
      setState(() => isPlayingNativeAudio = true);
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => isPlayingNativeAudio = false);
      });
    } catch (e) {
      debugPrint("Error reproduciendo audio: $e");
      if (mounted) setState(() => isPlayingNativeAudio = false);
    }
  }

  Future<void> _toggleRecordSpeech() async {
    if (answered || isEvaluatingAudio) return;

    if (isRecordingAudio) {
      setState(() {
        isRecordingAudio = false;
        isEvaluatingAudio = true;
      });

      final bytes = await _audioRecorder.stopRecording();
      if (!mounted) return;
      setState(() {
        recordedUserBytes = bytes;
        isEvaluatingAudio = false;
      });
    } else {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!mounted) return;
      if (hasPerm) {
        await _audioRecorder.startRecording();
        setState(() => isRecordingAudio = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Debes habilitar los permisos del micrófono."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _checkPronunciation() async {
    if (recordedUserBytes == null || answered) return;

    setState(() => isEvaluatingAudio = true);

    final String nativeAudioUrl =
        (currentQ['audio_url'] ?? currentQ['reference_audio_url'] ?? '').toString();
    final String expectedWord = (currentQ['expected_word'] ??
            currentQ['correct_phrase'] ??
            currentQ['word'] ??
            '')
        .toString();

    if (nativeAudioUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay audio nativo de referencia en esta lección."),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => isEvaluatingAudio = false);
      return;
    }

    final nativeBytes = await _audioRecorder.fetchAudioBytes(nativeAudioUrl);
    if (!mounted) return;

    if (nativeBytes != null) {
      final result = PhoneticMatcherService.compare(
        nativeWavBytes: nativeBytes,
        userWavBytes: recordedUserBytes!,
      );

      setState(() {
        answered = true;
        isEvaluatingAudio = false;
        lastAnswerWasCorrect = result.isPass;
        correctAnswerText = "$expectedWord (${result.feedback} - ${result.score}%)";
        if (!result.isPass) {
          localErrors++;
        }
      });

      if (!result.isPass) {
        _deductLifeOnMistake();
      }
    } else {
      setState(() => isEvaluatingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo descargar el audio nativo de referencia."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _nextQuestion() {
    if (widget.questions.isEmpty ||
        currentQuestionIndex >= widget.questions.length - 1) {
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
      case 'pronunciation':
      case 'fonetica':
      case 'habla':
        return _buildPronunciationView();
      case 'fill_blank':
      case 'completa_frase':
        return _buildFillBlankView();
      case 'order_phrase':
        return _buildOrderPhraseView();
      case 'multimedia':
        return _buildMultimediaView();
      case 'multiple_choice':
      default:
        return _buildMultipleChoiceView();
    }
  }

  Widget _buildTopCurvedHeader({required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.primaryYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.lessonTitle.isNotEmpty
                ? widget.lessonTitle
                : "Lección ${widget.currentIndexLesson + 1}",
            style: const TextStyle(
              fontFamily: 'Noot',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final int totalLessons = widget.totalLessons > 0 ? widget.totalLessons : 1;
    final int currentLesson = widget.currentIndexLesson;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(totalLessons, (index) {
                Color segmentColor;
                if (index < currentLesson) {
                  final int pastErrors =
                      (index < widget.lessonErrorsHistory.length)
                          ? widget.lessonErrorsHistory[index]
                          : 0;
                  segmentColor =
                      pastErrors > 0 ? Colors.redAccent : Colors.greenAccent;
                } else if (index == currentLesson) {
                  segmentColor = localErrors > 0
                      ? Colors.redAccent
                      : AppColors.primaryYellow;
                } else {
                  segmentColor = Colors.white.withValues(alpha: 0.25);
                }

                return Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    decoration: BoxDecoration(
                      color: segmentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 14),
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 4),
              Text(
                "$currentLives",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- VISTA 1: PRONUNCIACIÓN (FIGMA LECCIÓN 1) ---
  Widget _buildPronunciationView() {
    final String targetWord = (currentQ['expected_word'] ??
            currentQ['word'] ??
            currentQ['correct_phrase'] ??
            '¡Hola!')
        .toString();
    final String nativeAudioUrl =
        (currentQ['audio_url'] ?? currentQ['reference_audio_url'] ?? '').toString();

    final bool allowListen = currentQ['allow_listen'] ??
        currentQ['allow_preview_audio'] ??
        (currentQ['only_written'] != true);

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(
                subtitle: allowListen ? "Nueva palabra" : "Di la palabra"),
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 10.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Iconos/coco_con_sombrero.png',
                            height: 125,
                            width: 125,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/icono_app.png',
                              height: 105,
                              width: 105,
                              errorBuilder: (c, e, s) => const Icon(
                                  Icons.account_circle,
                                  size: 90,
                                  color: AppColors.primaryYellow),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 22, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  targetWord,
                                  style: const TextStyle(
                                    fontFamily: 'Noot',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              allowListen
                                  ? "Escucha la palabra con el botón 1 y luego repítela presionando el botón 2"
                                  : "Pronuncia la palabra al presionar el botón 2 sin escuchar el audio previo",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Positioned(
                            top: -8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: Color(0xFFFF4B4B),
                              child: Text(
                                "!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (allowListen) ...[
                            _buildActionButton(
                              badgeNumber: "1",
                              icon: isPlayingNativeAudio
                                  ? FontAwesomeIcons.volumeHigh
                                  : FontAwesomeIcons.volumeLow,
                              isActive: isPlayingNativeAudio,
                              onTap: () => _playNativeAudio(nativeAudioUrl),
                            ),
                            const SizedBox(width: 26),
                          ],
                          _buildActionButton(
                            badgeNumber: "2",
                            icon: isRecordingAudio
                                ? FontAwesomeIcons.stop
                                : FontAwesomeIcons.microphone,
                            isActive: isRecordingAudio,
                            activeColor: Colors.redAccent,
                            onTap: _toggleRecordSpeech,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isRecordingAudio
                            ? "Grabando... Tocá para parar"
                            : (recordedUserBytes != null
                                ? "Audio capturado. ¡Listo para comprobar!"
                                : "Tocá el botón 2 para hablar"),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isRecordingAudio
                              ? Colors.redAccent
                              : (recordedUserBytes != null
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white70),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (answered)
              _buildFeedbackBanner()
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    onPressed:
                        (recordedUserBytes == null || isEvaluatingAudio)
                            ? null
                            : _checkPronunciation,
                    child: isEvaluatingAudio
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Comprobar",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- VISTA 2: COMPLETA LA FRASE (FIGMA LECCIÓN 2) ---
  Widget _buildFillBlankView() {
    final String prompt = (currentQ['prompt_text'] ?? currentQ['question_text'] ?? 'Buenas').toString();
    final String fullTargetPhrase = (currentQ['full_phrase'] ?? currentQ['correct_phrase'] ?? '$prompt noches').toString();
    final String nativeAudioUrl = (currentQ['audio_url'] ?? currentQ['reference_audio_url'] ?? '').toString();
    final List<dynamic> options = (currentQ['question_options'] as List<dynamic>?) ?? [];

    String selectedOptionText = '';
    if (selectedOptionIndex != null && selectedOptionIndex! < options.length) {
      selectedOptionText = options[selectedOptionIndex!]['option_text'] ?? '';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(subtitle: "Completa la frase"),
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: Column(
                    children: [
                      Text(
                        prompt,
                        style: const TextStyle(
                          fontFamily: 'Noot',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Iconos/coco_durmiendo.png',
                            height: 120,
                            width: 120,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/icono_app.png',
                              height: 100,
                              width: 100,
                              errorBuilder: (c, e, s) => const Icon(
                                  Icons.bedtime_rounded,
                                  size: 80,
                                  color: AppColors.primaryYellow),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _playNativeAudio(nativeAudioUrl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 96,
                              width: 96,
                              decoration: BoxDecoration(
                                color: isPlayingNativeAudio
                                    ? const Color(0xFFFFD54F)
                                    : AppColors.primaryYellow,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.volumeHigh,
                                  size: 40,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(text: "$prompt "),
                            TextSpan(
                              text: selectedOptionText.isNotEmpty
                                  ? selectedOptionText
                                  : (answered ? fullTargetPhrase.replaceAll(prompt, '').trim() : "______"),
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primaryYellow,
                                decorationThickness: 2.5,
                                color: AppColors.primaryYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Column(
                        children: List.generate(options.length, (index) {
                          final option = options[index];
                          final String optionText = option['option_text'] ?? '';
                          final bool isCorrect = option['is_correct'] ?? false;

                          Color buttonColor = Colors.white;
                          Color textColor = Colors.black87;
                          Color borderColor = Colors.transparent;

                          if (selectedOptionIndex == index && !answered) {
                            buttonColor = AppColors.primaryYellow;
                            borderColor = Colors.white;
                          }

                          if (answered) {
                            if (isCorrect) {
                              buttonColor = const Color(0xFF28A745);
                              textColor = Colors.white;
                            } else if (selectedOptionIndex == index) {
                              buttonColor = const Color(0xFFDC3545);
                              textColor = Colors.white;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: textColor,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  side: BorderSide(color: borderColor, width: 2),
                                ),
                              ),
                              onPressed: answered
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedOptionIndex = index;
                                      });
                                    },
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (answered)
              _buildFeedbackBanner()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    onPressed: selectedOptionIndex == null
                        ? null
                        : () {
                            final isCorrect = options[selectedOptionIndex!]['is_correct'] ?? false;
                            _handleAnswerSelection(isCorrect, selectedOptionIndex!);
                          },
                    child: const Text(
                      "Comprobar",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Se declara dynamic icon para compatibilidad total con FalconData / IconData de FontAwesome
  Widget _buildActionButton({
    required String badgeNumber,
    required dynamic icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 104,
            width: 104,
            decoration: BoxDecoration(
              color: isActive
                  ? (activeColor ?? const Color(0xFFFFD54F))
                  : AppColors.primaryYellow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 42,
                color: const Color(0xFF5D4037),
              ),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                badgeNumber,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFF1E7E34) : const Color(0xFFC82333),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
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
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCorrect
                      ? "¡Excelente! Respuesta correcta"
                      : "¡Ups! Respuesta incorrecta",
                  style: const TextStyle(
                    fontFamily: 'Noot',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (correctAnswerText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Detalle: $correctAnswerText",
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _nextQuestion,
            child: const Text(
              "Continuar",
              style: TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionView() {
    final List<dynamic> options =
        currentQ.isNotEmpty ? (currentQ['question_options'] ?? []) : [];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(subtitle: "Palabras Nuevas"),
            _buildProgressBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: options.isEmpty
                    ? const Center(
                        child: Text(
                          "¡Prepárate para esta lección!",
                          style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white70,
                              fontSize: 16),
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
                            translation =
                                parts.length > 1 ? parts[1].trim() : '';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    wordTerm,
                                    style: const TextStyle(
                                      fontFamily: 'Noot',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  translation,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _nextQuestion,
                  child: const Text(
                    "Comenzar Lección",
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceView() {
    final String questionText = currentQ['question_text'] ?? '';
    final List<dynamic> options = currentQ['question_options'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(subtitle: "Selección Múltiple"),
            _buildProgressBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      questionText,
                      style: const TextStyle(
                        fontFamily: 'Noot',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final String optionText = option['option_text'] ?? '';
                          final bool isCorrect = option['is_correct'] ?? false;

                          Color buttonColor = Colors.white;
                          Color textColor = Colors.black87;
                          Color borderColor = Colors.transparent;

                          if (selectedOptionIndex == index && !answered) {
                            buttonColor = AppColors.primaryYellow;
                            borderColor = Colors.white;
                          }

                          if (answered) {
                            if (isCorrect) {
                              buttonColor = const Color(0xFF28A745);
                              textColor = Colors.white;
                            } else if (selectedOptionIndex == index) {
                              buttonColor = const Color(0xFFDC3545);
                              textColor = Colors.white;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  side: BorderSide(color: borderColor, width: 2),
                                ),
                                elevation: 2,
                              ),
                              onPressed: answered
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedOptionIndex = index;
                                      });
                                    },
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (answered)
              _buildFeedbackBanner()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    onPressed: selectedOptionIndex == null
                        ? null
                        : () {
                            final isCorrect = options[selectedOptionIndex!]['is_correct'] ?? false;
                            _handleAnswerSelection(isCorrect, selectedOptionIndex!);
                          },
                    child: const Text(
                      "Comprobar",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPhraseView() {
    final String questionText =
        currentQ['question_text'] ?? 'Ordena la palabra';
    final int cleanLength = correctAnswerText.replaceAll(' ', '').length;
    final int targetLength = cleanLength > 0
        ? cleanLength
        : (availableWords.isNotEmpty ? availableWords.length : 1);

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(subtitle: "Ordena la palabra"),
            _buildProgressBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  children: [
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
                    const SizedBox(height: 18),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
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
                                            color: hasLetter
                                                ? AppColors.primaryYellow
                                                : Colors.white30,
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
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
                          const SizedBox(height: 14),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            if (answered)
              _buildFeedbackBanner()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    onPressed: selectedWords.isEmpty ? null : _checkOrderPhrase,
                    child: const Text(
                      "Comprobar",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultimediaView() {
    final String questionText =
        currentQ['question_text'] ?? 'Escucha y selecciona';
    final List<dynamic> options = currentQ['question_options'] ?? [];
    final String audioUrl = (currentQ['audio_url'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCurvedHeader(subtitle: "Escucha el audio"),
            _buildProgressBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () => _playNativeAudio(audioUrl),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: isPlayingNativeAudio
                                ? const Color(0xFFFFD54F)
                                : AppColors.primaryYellow,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.volumeHigh,
                              size: 44,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final String optionText = option['option_text'] ?? '';
                          final bool isCorrect = option['is_correct'] ?? false;

                          Color buttonColor = Colors.white;
                          Color textColor = Colors.black87;
                          Color borderColor = Colors.transparent;

                          if (selectedOptionIndex == index && !answered) {
                            buttonColor = AppColors.primaryYellow;
                            borderColor = Colors.white;
                          }

                          if (answered) {
                            if (isCorrect) {
                              buttonColor = const Color(0xFF28A745);
                              textColor = Colors.white;
                            } else if (selectedOptionIndex == index) {
                              buttonColor = const Color(0xFFDC3545);
                              textColor = Colors.white;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  side: BorderSide(color: borderColor, width: 2),
                                ),
                              ),
                              onPressed: answered
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedOptionIndex = index;
                                      });
                                    },
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (answered)
              _buildFeedbackBanner()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 18.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    onPressed: selectedOptionIndex == null
                        ? null
                        : () {
                            final isCorrect = options[selectedOptionIndex!]['is_correct'] ?? false;
                            _handleAnswerSelection(isCorrect, selectedOptionIndex!);
                          },
                    child: const Text(
                      "Comprobar",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}