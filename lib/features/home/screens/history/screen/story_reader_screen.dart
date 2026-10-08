import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nicalingo/core/services/cache_service.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class StoryReaderScreen extends StatefulWidget {
  final Map<String, dynamic> story;
  final int storyNumber;
  final String targetLanguageName;

  const StoryReaderScreen({
    super.key,
    required this.story,
    this.storyNumber = 1,
    this.targetLanguageName = "Mískito",
  });

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  bool _isTranslated = false;
  Uint8List? _cachedImageBytes;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadImageOfflineSupport();
  }

  // Permite ver la portada incluso si se descargó una sola vez y luego no hay señal
  Future<void> _loadImageOfflineSupport() async {
    final imageUrl = (widget.story['content_image_asset'] ?? widget.story['image_asset'])?.toString();
    if (imageUrl == null || (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://'))) {
      return;
    }

    final cache = await CacheService.instance;
    final cacheKey = 'img_cache_${widget.story['id']}';

    // 1. Revisar si ya la teníamos guardada en local
    final cachedBase64 = cache.getData(cacheKey);
    if (cachedBase64 != null && cachedBase64 is String) {
      if (mounted) {
        setState(() {
          _cachedImageBytes = base64Decode(cachedBase64);
        });
      }
      return;
    }

    // 2. Si no estaba en local, descargarla una vez y guardarla para el futuro
    setState(() => _isLoadingImage = true);
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await cache.saveData(cacheKey, base64Encode(bytes));
        if (mounted) {
          setState(() {
            _cachedImageBytes = bytes;
            _isLoadingImage = false;
          });
        }
      }
    } catch (_) {
      // Sin internet y sin caché previa: se usará el fallback visual
      if (mounted) setState(() => _isLoadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Títulos dinámicos según el modo de traducción
    final originalTitle = widget.story['title'] ?? 'Historia';
    final translatedTitle = widget.story['title_translation'] ?? originalTitle;
    final currentTitle = _isTranslated ? translatedTitle : originalTitle;

    // Contenidos originales y traducidos basados en las columnas de library_stories
    final originalContent = widget.story['content'] ??
        widget.story['description'] ??
        'Contenido no disponible.';

    final translatedContent = widget.story['content_translation'] ??
        widget.story['description_translation'] ??
        'Traducción en preparación...';

    // Se prioriza la imagen ilustrativa interna si existe, o la portada
    final imageUrl = (widget.story['content_image_asset'] ?? widget.story['image_asset'])?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      currentTitle,
                      key: ValueKey<bool>(_isTranslated),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Noot',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                                  child: Align(
                                    alignment: Alignment.topLeft,
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
                                  ? "Viendo traducción al ${widget.targetLanguageName}"
                                  : "A continuación veremos su traducción al ${widget.targetLanguageName}",
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
    if (_cachedImageBytes != null) {
      return Image.memory(
        _cachedImageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.menu_book, size: 80, color: Colors.white),
      );
    }

    if (path == null || path.trim().isEmpty) {
      return Image.asset(
        'assets/images/mascara.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.menu_book, size: 80, color: Colors.white),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      if (_isLoadingImage) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryYellow, strokeWidth: 2),
        );
      }
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