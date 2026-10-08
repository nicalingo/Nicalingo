import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nicalingo/core/services/cache_service.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/home_perfil.dart';
import 'package:nicalingo/features/home/screens/home_settings.dart';
import 'package:nicalingo/features/home/screens/history/screen/loading_story_screen.dart';

class HomeBibliotecaScreen extends StatefulWidget {
  final String? currentLanguageCode;

  const HomeBibliotecaScreen({super.key, this.currentLanguageCode});

  @override
  State<HomeBibliotecaScreen> createState() => _HomeBibliotecaScreenState();
}

class _HomeBibliotecaScreenState extends State<HomeBibliotecaScreen> {
  final int _currentIndex = 2;
  int _selectedTab = 0;

  late Future<List<Map<String, dynamic>>> _storiesFuture;
  List<Map<String, dynamic>> _allStories = [];
  List<Map<String, dynamic>> _filteredStories = [];
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cached_library_stories';

  @override
  void initState() {
    super.initState();
    _storiesFuture = _fetchStories();
    _searchController.addListener(_filterStories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Procesa y formatea el JSON tanto si viene de Supabase como si viene de la caché
  List<Map<String, dynamic>> _mapStoriesResponse(List<dynamic> rawData) {
    return List<Map<String, dynamic>>.from(
      rawData.map((story) {
        final translations = story['library_story_translations'] as List<dynamic>? ?? [];

        final activeLang = (widget.currentLanguageCode ?? "Mískito").toLowerCase();
        final translation = translations.firstWhere(
          (t) {
            final langData = t['languages'] as Map<String, dynamic>?;
            final langName = (langData?['name'] ?? '').toString().toLowerCase();
            final langCode = (langData?['code'] ?? '').toString().toLowerCase();
            return langName.contains(activeLang) || langCode == activeLang;
          },
          orElse: () => translations.isNotEmpty ? translations.first : <String, dynamic>{},
        ) as Map<String, dynamic>;

        return {
          'id': story['id'],
          'image_asset': story['image_asset'],
          'content_image_asset': story['content_image_asset'],
          'tag': story['tag'],
          'author': story['author'],
          'title': story['title'] ?? 'Sin título',
          'description': story['description'] ?? '',
          'content': story['content'] ?? story['description'] ?? '',
          'title_translation': translation['title'] ?? story['title'],
          'description_translation': translation['description'] ?? story['description'],
          'content_translation': translation['content'] ?? translation['description'],
          'translations': translations,
        };
      }),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStories() async {
    final cache = await CacheService.instance;

    // 1. Revisar si hay conexión a internet
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = !connectivity.contains(ConnectivityResult.none);

    if (hasInternet) {
      try {
        final response = await Supabase.instance.client
            .from('library_stories')
            .select('''
              id,
              title,
              description,
              content,
              image_asset,
              content_image_asset,
              tag,
              author,
              library_story_translations (
                title,
                description,
                content,
                language_id,
                languages (
                  id,
                  name,
                  code
                )
              )
            ''')
            .order('id', ascending: true);

        // Guardar copia fresca en caché
        await cache.saveData(_cacheKey, response);

        final stories = _mapStoriesResponse(response as List<dynamic>);

        if (mounted) {
          setState(() {
            _allStories = stories;
            _filteredStories = stories;
          });
        }
        return stories;
      } catch (e) {
        debugPrint('Error de red al consultar Supabase, usando caché: $e');
        // Si Supabase falla por señal inestable, cae a la caché local
        return _loadFromCache(cache);
      }
    } else {
      // 2. Modo Offline: Cargar directamente desde el caché local
      return _loadFromCache(cache);
    }
  }

  List<Map<String, dynamic>> _loadFromCache(CacheService cache) {
    final cachedData = cache.getData(_cacheKey);
    if (cachedData != null && cachedData is List) {
      final stories = _mapStoriesResponse(cachedData);
      if (mounted) {
        setState(() {
          _allStories = stories;
          _filteredStories = stories;
        });
      }
      return stories;
    }
    return [];
  }

  Future<void> _refreshStories() async {
    _searchController.clear();
    setState(() {
      _storiesFuture = _fetchStories();
    });
    await _storiesFuture;
  }

  void _filterStories() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStories = _allStories;
      } else {
        _filteredStories = _allStories.where((story) {
          final title = (story['title'] ?? '').toString().toLowerCase();
          final titleTrans = (story['title_translation'] ?? '').toString().toLowerCase();
          final desc = (story['description'] ?? '').toString().toLowerCase();
          final tag = (story['tag'] ?? '').toString().toLowerCase();
          final author = (story['author'] ?? '').toString().toLowerCase();

          return title.contains(query) ||
              titleTrans.contains(query) ||
              desc.contains(query) ||
              tag.contains(query) ||
              author.contains(query);
        }).toList();
      }
    });
  }

  void _onNavBarTap(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePerfilScreen(),
        ),
      );
      return;
    }

    if (index == 1) {
      Navigator.pop(context);
      return;
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeSettingsScreen(),
        ),
      );
      return;
    }
  }

  Widget _buildStoryImage({
    required String? imageUrl,
    required double size,
    required Color iconColor,
    required IconData iconFallback,
    double iconSize = 28,
  }) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Icon(iconFallback, color: iconColor, size: iconSize);
    }

    final path = imageUrl.trim();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            Icon(iconFallback, color: iconColor, size: iconSize),
      );
    }

    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(iconFallback, color: iconColor, size: iconSize),
    );
  }

  Widget _buildSegmentedSwitch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withAlpha(200),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.textWhite, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitchItem(title: "Biblioteca", index: 0, icon: Icons.menu_book_rounded),
          _buildSwitchItem(title: "Minijuegos", index: 1, icon: Icons.sports_esports_rounded),
        ],
      ),
    );
  }

  Widget _buildSwitchItem({required String title, required int index, required IconData icon}) {
    final bool isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        if (_selectedTab != index) {
          setState(() {
            _selectedTab = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.textDark : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.textDark : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArcadeView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
        padding: const EdgeInsets.only(bottom: 110),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildArcadeCard(
            title: "Come con Coco",
            tag: "Refuerzo",
            imageAsset: "assets/images/arcade/icononos/come_coco.jpeg",
            cardColor: const Color(0xFFFFD180),
            isEnabled: true,
            actionText: "Jugar",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Iniciando Come con Coco...')),
              );
            },
          ),
          _buildArcadeCard(
            title: "Memoria Ancestral",
            tag: "Cartas",
            icon: Icons.style_rounded,
            cardColor: const Color(0xFF80D8FF),
            isEnabled: true,
            actionText: "Jugar",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Iniciando Memoria Ancestral...')),
              );
            },
          ),
          _buildArcadeCard(
            title: "Trivia Cultural",
            tag: "Multijugador",
            icon: Icons.psychology_alt_rounded,
            cardColor: const Color(0xFFA7FFEB),
            isEnabled: true,
            actionText: "Jugar",
            onTap: () {
              _showTriviaModeDialog();
            },
          ),
          _buildArcadeCard(
            title: "Repite con Coco",
            tag: "Voz / Habla",
            icon: Icons.record_voice_over_rounded,
            cardColor: const Color(0xFFD1C4E9),
            isEnabled: false,
            actionText: "Jugar",
            onTap: () {},
          ),
          _buildArcadeCard(
            title: "Diccionario Coco",
            tag: "Consulta",
            icon: Icons.auto_stories_rounded,
            cardColor: const Color(0xFFFFE082),
            isEnabled: true,
            actionText: "Abrir",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Abriendo Diccionario de Coco...')),
              );
            },
          ),
          _buildArcadeCard(
            title: "LingoClip",
            tag: "Canciones",
            icon: Icons.music_note_rounded,
            cardColor: const Color(0xFFFF80AB),
            isEnabled: false,
            actionText: "Jugar",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildArcadeCard({
    required String title,
    required String tag,
    String? imageAsset,
    IconData? icon,
    required Color cardColor,
    required bool isEnabled,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withAlpha(235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: imageAsset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        imageAsset,
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.sports_esports_rounded,
                          size: 52,
                          color: Colors.black87.withAlpha(180),
                        ),
                      ),
                    )
                  : Icon(
                      icon ?? Icons.sports_esports_rounded,
                      size: 52,
                      color: Colors.black87.withAlpha(180),
                    ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: isEnabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? const Color(0xFFFF9100) : Colors.grey.shade400,
                foregroundColor: Colors.white,
                elevation: isEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEnabled ? actionText : 'Pronto',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTriviaModeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Elige el modo de Trivia',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFA7FFEB),
                  child: Icon(Icons.person, color: Colors.black87),
                ),
                title: const Text('Partida Solitaria', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Compite contra tu propio récord personal'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFD180),
                  child: Icon(Icons.group, color: Colors.black87),
                ),
                title: const Text('Multijugador en Sala', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Crea una sala o únete mediante código'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageName = widget.currentLanguageCode ?? "Mískito";

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Iconos/background/home_back.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildSegmentedSwitch(),
                const SizedBox(height: 15),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _selectedTab == 1
                        ? _buildArcadeView()
                        : Column(
                            key: const ValueKey('library_view'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.textWhite,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(30),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: "Buscar por título o etiqueta...",
                                      hintStyle: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Expanded(
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _storiesFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting &&
                                        _allStories.isEmpty) {
                                      return const Center(
                                        child: CircularProgressIndicator(color: AppColors.primaryYellow),
                                      );
                                    }

                                    final stories = _filteredStories;

                                    return RefreshIndicator(
                                      color: AppColors.textDark,
                                      backgroundColor: AppColors.primaryYellow,
                                      onRefresh: _refreshStories,
                                      child: stories.isEmpty
                                          ? ListView(
                                              physics: const AlwaysScrollableScrollPhysics(
                                                parent: BouncingScrollPhysics(),
                                              ),
                                              children: [
                                                SizedBox(
                                                  height: MediaQuery.of(context).size.height * 0.6,
                                                  child: Center(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 30),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Image.asset(
                                                            'assets/images/coco_ups.png',
                                                            width: 140,
                                                            height: 140,
                                                            fit: BoxFit.contain,
                                                          ),
                                                          const SizedBox(height: 20),
                                                          const Text(
                                                            "¡Ups!",
                                                            style: TextStyle(
                                                              fontFamily: 'Inter',
                                                              fontSize: 22,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.textWhite,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          const Text(
                                                            "Estamos trabajando para integrarte nuevas historias",
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              fontFamily: 'Inter',
                                                              fontSize: 15,
                                                              color: Colors.white70,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : SingleChildScrollView(
                                              physics: const AlwaysScrollableScrollPhysics(
                                                parent: BouncingScrollPhysics(),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    height: 130,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.secondarySkyBlue.withAlpha(200),
                                                      borderRadius: BorderRadius.circular(22),
                                                      border: Border.all(
                                                        color: AppColors.textWhite.withAlpha(80),
                                                        width: 1.8,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withAlpha(30),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(16.0),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Text(
                                                                  stories[0]['title'] ?? 'Historia',
                                                                  style: const TextStyle(
                                                                    fontFamily: 'Inter',
                                                                    color: AppColors.textWhite,
                                                                    fontSize: 18,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 8),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (context) => LoadingStoryScreen(
                                                                          story: stories[0],
                                                                          storyNumber: 1,
                                                                          targetLanguageName: languageName,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 12,
                                                                      vertical: 4,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: AppColors.primaryYellow,
                                                                      borderRadius: BorderRadius.circular(12),
                                                                    ),
                                                                    child: const Text(
                                                                      "Iniciar",
                                                                      style: TextStyle(
                                                                        fontFamily: 'Inter',
                                                                        color: AppColors.textDark,
                                                                        fontWeight: FontWeight.bold,
                                                                        fontSize: 12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Center(
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(16),
                                                              child: SizedBox(
                                                                width: 75,
                                                                height: 75,
                                                                child: _buildStoryImage(
                                                                  imageUrl: stories[0]['image_asset'] ?? stories[0]['content_image_asset'],
                                                                  size: 75,
                                                                  iconColor: AppColors.textWhite,
                                                                  iconFallback: Icons.menu_book,
                                                                  iconSize: 36,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 25),
                                                  const Text(
                                                    "Continuar historias interactivas",
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textWhite,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: stories.length,
                                                    itemBuilder: (context, index) {
                                                      final story = stories[index];

                                                      return Container(
                                                        margin: const EdgeInsets.only(bottom: 12),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primaryBlue.withAlpha(160),
                                                          borderRadius: BorderRadius.circular(22),
                                                          border: Border.all(
                                                            color: AppColors.textWhite.withAlpha(50),
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withAlpha(20),
                                                              blurRadius: 6,
                                                              offset: const Offset(0, 3),
                                                            ),
                                                          ],
                                                        ),
                                                        child: ListTile(
                                                          contentPadding: const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 8,
                                                          ),
                                                          leading: ClipRRect(
                                                            borderRadius: BorderRadius.circular(12),
                                                            child: SizedBox(
                                                              width: 45,
                                                              height: 45,
                                                              child: _buildStoryImage(
                                                                imageUrl: story['image_asset'] ?? story['content_image_asset'],
                                                                size: 45,
                                                                iconColor: AppColors.textWhite,
                                                                iconFallback: Icons.auto_stories,
                                                                iconSize: 24,
                                                              ),
                                                            ),
                                                          ),
                                                          title: Text(
                                                            story['title'] ?? '',
                                                            style: const TextStyle(
                                                              fontFamily: 'Inter',
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 15,
                                                              color: AppColors.textWhite,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            story['description'] ?? '',
                                                            style: const TextStyle(
                                                              fontFamily: 'Inter',
                                                              fontSize: 12,
                                                              color: Colors.white70,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          trailing: const Icon(
                                                            Icons.arrow_forward_ios_rounded,
                                                            size: 16,
                                                            color: AppColors.textWhite,
                                                          ),
                                                          onTap: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => LoadingStoryScreen(
                                                                  story: story,
                                                                  storyNumber: index + 1,
                                                                  targetLanguageName: languageName,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 100),
                                                ],
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
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
          child: SizedBox(
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withAlpha(240),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.textWhite.withAlpha(220),
                      width: 2.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavBarItem('assets/images/Iconos/Icon_barra/user_icon.png', 0),
                      _buildNavBarItem('assets/images/Iconos/Icon_barra/Map_icon.png', 1),
                      _buildNavBarItem('assets/images/Iconos/Icon_barra/Biblioteca_icon.png', 2),
                      _buildNavBarItem('assets/images/Iconos/Icon_barra/Ajustes_icon.png', 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(String assetPath, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavBarTap(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withAlpha(200),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ]
              : [],
        ),
        child: Image.asset(
          assetPath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}