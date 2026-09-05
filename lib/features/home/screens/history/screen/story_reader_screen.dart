import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class StoryReaderScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  final int storyNumber;

  const StoryReaderScreen({
    super.key,
    required this.story,
    this.storyNumber = 1,
  });

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  bool _isTranslated = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.story['title'] ?? 'Historia';
    final originalContent = widget.story['content'] ??
        widget.story['description'] ??
        'Contenido no disponible.';
    final translatedContent = widget.story['content_translation'] ??
        'Traducción en preparación...';
    final imageUrl = widget.story['image_asset']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Noot',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: _buildStoryCover(imageUrl),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8BC34A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(50),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _isTranslated ? translatedContent : originalContent,
                                    key: ValueKey<bool>(_isTranslated),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isTranslated
                                  ? "Viendo traducción al Mískito"
                                  : "A continuación veremos su traducción al Mískito",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 170,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF29B6F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: () {
                                  if (!_isTranslated) {
                                    setState(() {
                                      _isTranslated = true;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Text(
                                  _isTranslated ? "Terminar" : "Continuar",
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(10, 10),
                        child: Image.asset(
                          'assets/images/coco_bandera.png',
                          width: 125,
                          height: 125,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.flag, size: 70, color: AppColors.primaryYellow),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 70,
      decoration: const BoxDecoration(
        color: AppColors.primaryYellow,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(55),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Text(
              "Lectura ${widget.storyNumber}",
              style: const TextStyle(
                fontFamily: 'Noot',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCover(String? path) {
    if (path == null || path.trim().isEmpty) {
      return Image.asset(
        'assets/images/mascara.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.menu_book, size: 80, color: Colors.white),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryYellow, strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.menu_book, size: 80, color: Colors.white),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.menu_book, size: 80, color: Colors.white),
    );
  }
}