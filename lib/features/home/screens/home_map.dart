import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/levels/screens/loading_level_screen.dart';
import 'package:nicalingo/features/home/screens/home_biblioteca.dart';
import 'package:nicalingo/features/home/screens/home_perfil.dart';

class _PathNode {
  final String id;
  final Offset position; 
  final String? number;
  final String? iconPath;
  final Color color;
  final Color ringColor;
  final String title;
  final bool isUnlocked;

  const _PathNode({
    required this.id,
    required this.position,
    required this.number,
    this.iconPath,
    this.color = Colors.white,
    this.ringColor = Colors.white,
    required this.title,
    required this.isUnlocked,
  });
}

class HomeMapScreen extends StatefulWidget {
  final int languageId; 
  
  const HomeMapScreen({super.key, this.languageId = 1});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  int _currentIndex = 1;
  String _currentHeaderTitle = "Niveles";
  List<Map<String, dynamic>> _dbLevelsCache = [];
  
  // Quitamos el 'final' para permitir reasignar y actualizar el Future al volver del nivel
  late Future<List<Map<String, dynamic>>> _levelsFuture = _fetchLevelsAndProgress();

  static const List<double> _waveXPattern = [0.26, 0.74, 0.25, 0.74];
  final List<String> _defaultTitles = ['conectores', 'familia', 'pronombres', 'saludos'];

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
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeBibliotecaScreen(),
        ),
      );
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Próximamente disponible 🚀"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleScrollUpdate(ScrollNotification notification) {
    if (_dbLevelsCache.isEmpty) return;
    
    final scrollOffset = notification.metrics.pixels;
    final targetY = scrollOffset + 120.0;

    String activeTitle = _dbLevelsCache.first['lesson_title'];
    double minDistance = double.infinity;

    for (int i = 0; i < _dbLevelsCache.length; i++) {
      final double nodeY = 90.0 + (i * 130.0);
      final double distance = (nodeY - targetY).abs();

      if (distance < minDistance) {
        minDistance = distance;
        activeTitle = _dbLevelsCache[i]['lesson_title'];
      }
    }

    if (activeTitle != _currentHeaderTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && activeTitle != _currentHeaderTitle) {
          setState(() {
            _currentHeaderTitle = activeTitle;
          });
        }
      });
    }
  }

  String _getIconPathForTitle(String title, int index) {
    String rawTitle = title;
    if (title.isEmpty || title.toLowerCase().startsWith('nivel')) {
      rawTitle = _defaultTitles[index % _defaultTitles.length];
    }

    final normalized = rawTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    return 'assets/images/Iconos/Icon_niveles/$normalized.png';
  }

  Future<List<Map<String, dynamic>>> _fetchLevelsAndProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final levelsResponse = await Supabase.instance.client
          .from('levels')
          .select()
          .eq('language_id', widget.languageId)
          .order('level_number', ascending: true);

      if (levelsResponse.isEmpty) return [];

      Set<int> completedLevelIds = {};
      if (userId != null) {
        try {
          final progressResponse = await Supabase.instance.client
              .from('user_progress')
              .select('level_id, is_completed')
              .eq('user_id', userId);

          for (var p in progressResponse) {
            if (p['is_completed'] == true) {
              completedLevelIds.add(p['level_id']);
            }
          }
        } catch (e) {
          debugPrint('Aviso cargando user_progress: $e');
        }
      }

      List<Map<String, dynamic>> enrichedLevels = [];

      for (int i = 0; i < levelsResponse.length; i++) {
        final level = levelsResponse[i];
        final levelPkId = level['id'];
        
        final lessonResponse = await Supabase.instance.client
            .from('lessons')
            .select('title')
            .eq('level_id', levelPkId)
            .eq('lesson_number', 1)
            .maybeSingle();

        String lessonTitle = lessonResponse?['title'] ?? level['title'] ?? 'Nivel ${level['level_number']}';
        
        bool isUnlocked = false;
        if (i == 0) {
          isUnlocked = true;
        } else {
          final prevLevelPkId = levelsResponse[i - 1]['id'];
          if (completedLevelIds.contains(prevLevelPkId)) {
            isUnlocked = true;
          }
        }

        enrichedLevels.add({
          ...level,
          'lesson_title': lessonTitle,
          'is_unlocked': isUnlocked,
        });
      }

      return enrichedLevels;
    } catch (e) {
      debugPrint('Error cargando niveles: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _levelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));
                }

                final dbLevels = snapshot.data ?? [];
                _dbLevelsCache = dbLevels;

                if (dbLevels.isNotEmpty && _currentHeaderTitle == "Niveles") {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _currentHeaderTitle = dbLevels[0]['lesson_title'];
                      });
                    }
                  });
                }

                int totalLevels = dbLevels.isNotEmpty ? dbLevels.length : 4;
                const double verticalSpacing = 130.0;
                double dynamicMapHeight = max(size.height * 0.8, (totalLevels * verticalSpacing) + 200.0);

                List<_PathNode> pathNodes = [];
                for (int i = 0; i < dbLevels.length; i++) {
                  final levelData = dbLevels[i];
                  final title = levelData['lesson_title'] ?? 'Nivel ${i + 1}';
                  final levelNumber = levelData['level_number'] ?? (i + 1);
                  final bool isUnlocked = levelData['is_unlocked'] ?? false;

                  double dx = _waveXPattern[i % _waveXPattern.length];
                  double dy = (90.0 + (i * verticalSpacing)) / dynamicMapHeight;

                  final colors = [
                    const Color(0xFF34B3E4),
                    const Color(0xFF0055FF),
                    const Color(0xFFFF6622),
                    const Color(0xFFFF9900),
                  ];
                  
                  final nodeColor = isUnlocked ? colors[i % colors.length] : Colors.grey.shade600;
                  final ringColor = isUnlocked ? ((i == 0) ? const Color(0xFF8FE388) : Colors.white) : Colors.grey.shade400;

                  pathNodes.add(_PathNode(
                    id: levelData['id']?.toString() ?? '${i + 1}',
                    position: Offset(dx, dy),
                    number: levelNumber.toString(),
                    iconPath: _getIconPathForTitle(title, i),
                    color: nodeColor,
                    ringColor: ringColor,
                    title: title,
                    isUnlocked: isUnlocked,
                  ));
                }

                return Stack(
                  children: [
                    Positioned(
                      top: 60,
                      right: -30,
                      child: Transform.rotate(
                        angle: -20 * pi / 180,
                        child: Image.asset(
                          'assets/images/coco_bandera.png',
                          width: 130,
                          height: 150,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 130, 
                      left: -20,
                      child: Image.asset(
                        'assets/images/coco_bandera.png',
                        width: 140,
                        height: 200,
                      ),
                    ),
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          _handleScrollUpdate(notification);
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 80.0, bottom: 200.0),
                        child: Column(
                          children: [
                            SizedBox(
                              height: dynamicMapHeight,
                              child: _buildLevelPath(dynamicMapHeight, context, pathNodes), 
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
                child: Text(
                  _currentHeaderTitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
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

  Widget _buildLevelPath(double mapHeight, BuildContext context, List<_PathNode> pathNodes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = pathNodes
            .map((n) => Offset(n.position.dx * width, n.position.dy * mapHeight))
            .toList();

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedPathPainter(points: centers),
              ),
            ),
            for (int i = 0; i < pathNodes.length; i++)
              ..._buildNodeWithShadow(pathNodes[i], centers[i], context),
          ],
        );
      },
    );
  }

  List<Widget> _buildNodeWithShadow(_PathNode node, Offset center, BuildContext context) {
    final nodeSize = 85.0;

    return [
      Positioned(
        left: center.dx - nodeSize * 0.4,
        top: center.dy + nodeSize / 2 - 8,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: nodeSize * 0.8,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ),
      Positioned(
        left: center.dx - nodeSize / 2,
        top: center.dy - nodeSize / 2,
        child: _buildLevelNode(node: node, size: nodeSize, context: context),
      ),
    ];
  }

  Widget _buildLevelNode({required _PathNode node, required double size, required BuildContext context}) {
    return GestureDetector(
      onTap: () async {
        if (!node.isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🔒 Debes completar el nivel anterior para desbloquear este"),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        String loadingTitle = "Cargando ${node.title}...";
        int levelNumber = int.tryParse(node.number ?? '1') ?? 1;
        int? specificId = int.tryParse(node.id);

        // Esperamos a que el usuario termine el nivel y regrese
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingLevelScreen(
              languageId: widget.languageId,
              levelNumber: levelNumber,
              specificLevelId: specificId,
              levelTitle: loadingTitle,
            ),
          ),
        );

        // Al volver, si el nivel se completó con éxito, recargamos el mapa consultando de nuevo Supabase
        if (result == true && mounted) {
          setState(() {
            _levelsFuture = _fetchLevelsAndProgress();
          });
        }
      },
      child: SizedBox(
        width: size + 5,
        height: size + 15,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: node.color,
                shape: BoxShape.circle,
                border: Border.all(color: node.ringColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: node.isUnlocked
                    ? Image.asset(
                        node.iconPath!, 
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.menu_book, color: Colors.white, size: 30);
                        },
                      )
                    : const Icon(Icons.lock, color: Colors.white, size: 32),
              ),
            ),
            if (node.number != null)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    node.number!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

class _DashedPathPainter extends CustomPainter {
  final List<Offset> points;
  const _DashedPathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midY = current.dy + (next.dy - current.dy) / 2;
      path.cubicTo(current.dx, midY, next.dx, midY, next.dx, next.dy);
    }
    final paint = Paint()
      ..color = Colors.white.withAlpha(130)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? 9.0 : 9.0;
        final end = min(distance + segmentLength, metric.length);
        if (draw) canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => oldDelegate.points != points;
}