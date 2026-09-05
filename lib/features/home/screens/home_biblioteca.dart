import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/home_perfil.dart';
import 'package:nicalingo/features/home/screens/history/screen/loading_story_screen.dart';

class HomeBibliotecaScreen extends StatefulWidget {
  const HomeBibliotecaScreen({super.key});

  @override
  State<HomeBibliotecaScreen> createState() => _HomeBibliotecaScreenState();
}

class _HomeBibliotecaScreenState extends State<HomeBibliotecaScreen> {
  int _currentIndex = 2;
  
  late final Future<List<Map<String, dynamic>>> _storiesFuture = _fetchStories();
  List<Map<String, dynamic>> _allStories = [];
  List<Map<String, dynamic>> _filteredStories = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchStories() async {
    try {
      final response = await Supabase.instance.client
          .from('library_stories')
          .select()
          .order('id', ascending: true);

      final List<Map<String, dynamic>> stories = List<Map<String, dynamic>>.from(response);
      _allStories = stories;
      _filteredStories = stories;
      return stories;
    } catch (e) {
      debugPrint('Error cargando historias: $e');
      return [];
    }
  }

  void _filterStories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStories = _allStories.where((story) {
        final title = story['title']?.toLowerCase() ?? '';
        return title.contains(query);
      }).toList();
    });
  }

  void _onNavBarTap(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      Navigator.push(
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

    setState(() {
      _currentIndex = index;
    });

    if (index != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Próximamente disponible"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Widget para cargar la portada usando la URL de Supabase
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

    // Si es URL web / Supabase Storage
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

    // Por si en algún momento colocas un asset local
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(iconFallback, color: iconColor, size: iconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "Biblioteca",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        hintText: "Buscar historia...",
                        hintStyle: TextStyle(fontFamily: 'Inter', color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _storiesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));
                      }

                      final stories = _filteredStories;

                      if (stories.isEmpty) {
                        return Center(
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
                                    color: Colors.white,
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
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tarjeta Principal (Destacada)
                            Container(
                              height: 130,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(40),
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
                                            stories[0]['title'] ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              color: Colors.white,
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
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryYellow,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                "Iniciar",
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  color: Colors.black87,
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
                                            imageUrl: stories[0]['image_asset'],
                                            size: 75,
                                            iconColor: Colors.white,
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
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Lista de Historias
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: stories.length,
                              itemBuilder: (context, index) {
                                final story = stories[index];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(20),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 45,
                                        height: 45,
                                        child: _buildStoryImage(
                                          imageUrl: story['image_asset'],
                                          size: 45,
                                          iconColor: Colors.black54,
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
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      story['description'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black54),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoadingStoryScreen(
                                            story: story,
                                            storyNumber: index + 1,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
    );
  }

  Widget _buildNavBarItem(String assetPath, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavBarTap(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Image.asset(
          assetPath,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}