import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/levels/screens/loading_level_screen.dart';
import 'package:nicalingo/features/home/screens/home_biblioteca.dart';
import 'package:nicalingo/features/home/screens/home_perfil.dart';
import 'package:nicalingo/features/home/screens/home_settings.dart';

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
  Map<String, dynamic>? _userProfile;
  int _currentLives = 5;
  int _secondsUntilNextLife = 0;
  Timer? _countdownTimer;

  late Future<List<Map<String, dynamic>>> _levelsFuture =
      _fetchLevelsAndProgress();

  static const List<double> _waveXPattern = [0.26, 0.74, 0.25, 0.74];
  final List<String> _defaultTitles = [
    'conectores',
    'familia',
    'pronombres',
    'saludos'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsUntilNextLife > 0) {
        setState(() {
          _secondsUntilNextLife--;
        });
      } else if (_currentLives < 5) {
        // Cuando llega a 0 y no está lleno, vuelve a sincronizar con Supabase automáticamente
        _fetchUserProfile();
      }
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      _fetchUserProfile(),
      (() async {
        setState(() {
          _levelsFuture = _fetchLevelsAndProgress();
        });
      })(),
    ]);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final livesRpc = await Supabase.instance.client.rpc(
        'get_or_restore_lives',
        params: {'user_uuid': user.id},
      );

      int syncedLives = 5;
      int secondsLeft = 0;

      if (livesRpc is List && livesRpc.isNotEmpty) {
        syncedLives = (livesRpc.first['current_lives'] as int?) ?? 5;
        secondsLeft = (livesRpc.first['seconds_until_next'] as int?) ?? 0;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _currentLives = syncedLives;
          _secondsUntilNextLife = secondsLeft;
        });
      }
    } catch (e) {
      debugPrint('Error cargando perfil o vidas: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Buenos días';
    } else if (hour >= 12 && hour < 19) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showNoLivesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.favorite_border, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('¡Sin vidas!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Te has quedado sin vidas para jugar este nivel.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_secondsUntilNextLife > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Próxima vida en: ${_formatTime(_secondsUntilNextLife)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  void _showLivesInfoModal() {
    final bool isAdmin = _userProfile?['role'] == 'admin';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Vidas ($_currentLives/5)',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentLives == 5)
              const Text('¡Tus vidas están al máximo!')
            else
              Text(
                  'Se regenera 1 vida cada 30 minutos.\nSiguiente vida en: ${_formatTime(_secondsUntilNextLife)}'),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bolt, color: Colors.black87),
                  label: const Text(
                    'Restablecer vidas a full',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAdminRestoreLivesDialog();
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAdminRestoreLivesDialog() {
    final TextEditingController passController = TextEditingController();
    const String adminSecret = "210406";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.healing, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Restablecer Vidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa la contraseña de administrador para restablecer las vidas al máximo (5/5).',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contraseña de admin',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (passController.text.trim() == adminSecret) {
                Navigator.pop(context);
                await _adminRestoreLives();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña incorrecta'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Restablecer',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _adminRestoreLives() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.rpc(
        'admin_restore_user_lives',
        params: {'user_uuid': user.id},
      );

      if (mounted) {
        setState(() {
          _currentLives = 5;
          _secondsUntilNextLife = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Vidas restablecidas al máximo (5/5)! ❤️'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error restableciendo vidas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restablecer vidas: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAdminBypassDialog(BuildContext context, _PathNode node) {
    final TextEditingController passController = TextEditingController();
    const String adminSecret = "210406";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.black87),
            SizedBox(width: 8),
            Text(
              'Modo Desarrollador',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nivel: ${node.title} (ID: ${node.id})',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contraseña de anulación',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (passController.text.trim() == adminSecret) {
                Navigator.pop(context);
                _launchLevel(node);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña incorrecta'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Acceder',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchLevel(_PathNode node) async {
    String loadingTitle = "Cargando ${node.title}...";
    int levelNumber = int.tryParse(node.number ?? '1') ?? 1;
    int? specificId = int.tryParse(node.id);

    await Navigator.push(
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

    // Al regresar del nivel, actualiza vidas y progreso de inmediato
    if (mounted) {
      await _refreshAllData();
    }
  }

  void _onNavBarTap(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePerfilScreen(),
        ),
      ).then((_) => _fetchUserProfile());
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

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeSettingsScreen(),
        ),
      ).then((_) => _fetchUserProfile());
      return;
    }
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

      Set<int> completedLevelKeys = {};
      int maxCurrentLevel = 1;

      if (userId != null) {
        try {
          final progressResponse = await Supabase.instance.client
              .from('user_progress')
              .select('level_id, current_level_id, is_completed')
              .eq('user_id', userId)
              .eq('language_id', widget.languageId);

          for (var p in progressResponse) {
            final isDone = p['is_completed'] == true ||
                p['is_completed'] == 'true' ||
                p['is_completed'] == 1;

            if (isDone) {
              if (p['level_id'] != null) {
                final parsedId = int.tryParse(p['level_id'].toString());
                if (parsedId != null) completedLevelKeys.add(parsedId);
              }
              if (p['current_level_id'] != null) {
                final parsedCurr = int.tryParse(p['current_level_id'].toString());
                if (parsedCurr != null) {
                  completedLevelKeys.add(parsedCurr);
                  if (parsedCurr > maxCurrentLevel) {
                    maxCurrentLevel = parsedCurr;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Aviso cargando user_progress: $e');
        }
      }

      List<Map<String, dynamic>> enrichedLevels = [];

      for (int i = 0; i < levelsResponse.length; i++) {
        final level = levelsResponse[i];
        final int levelPkId = int.tryParse(level['id'].toString()) ?? 0;
        final int levelNum =
            int.tryParse(level['level_number'].toString()) ?? (i + 1);

        final lessonResponse = await Supabase.instance.client
            .from('lessons')
            .select('title')
            .eq('level_id', levelPkId)
            .order('lesson_number', ascending: true)
            .limit(1)
            .maybeSingle();

        String lessonTitle = lessonResponse?['title'] ??
            level['title'] ??
            'Nivel $levelNum';

        bool isUnlocked = false;

        if (i == 0) {
          isUnlocked = true;
        } else {
          final prevLevel = levelsResponse[i - 1];
          final int prevPkId = int.tryParse(prevLevel['id'].toString()) ?? 0;
          final int prevNum =
              int.tryParse(prevLevel['level_number'].toString()) ?? i;

          final bool prevIsDone = completedLevelKeys.contains(prevPkId) ||
              completedLevelKeys.contains(prevNum);
          final bool currentIsDone = completedLevelKeys.contains(levelPkId) ||
              completedLevelKeys.contains(levelNum);

          if (prevIsDone || currentIsDone || levelNum <= (maxCurrentLevel + 1) || levelPkId <= (maxCurrentLevel + 1)) {
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
      debugPrint('Error en _fetchLevelsAndProgress: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final nickname = _userProfile?['nickname'] ?? 'NicaLingo';
    final avatarUrl = _userProfile?['avatar_url'];
    final streak = _userProfile?['streak'] ?? 0;

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
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryYellow));
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
                double dynamicMapHeight = max(
                    size.height * 0.8, (totalLevels * verticalSpacing) + 200.0);

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

                  final nodeColor = isUnlocked
                      ? colors[i % colors.length]
                      : Colors.grey.shade600;
                  final ringColor = isUnlocked
                      ? ((i == 0) ? const Color(0xFF8FE388) : Colors.white)
                      : Colors.grey.shade400;

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
                      top: 130,
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
                      child: RefreshIndicator(
                        color: Colors.black87,
                        backgroundColor: AppColors.primaryYellow,
                        onRefresh: _refreshAllData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(
                              left: 20.0,
                              right: 20.0,
                              top: 150.0,
                              bottom: 200.0),
                          child: Column(
                            children: [
                              SizedBox(
                                height: dynamicMapHeight,
                                child: _buildLevelPath(
                                    dynamicMapHeight, context, pathNodes),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Header Superior Fijo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopHeader(nickname, avatarUrl, streak, _currentLives),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(45),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentHeaderTitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Barra inferior unificada con Liquid Glass amarillo y efecto 3D
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
                    border: Border.all(color: AppColors.textWhite.withAlpha(220), width: 2.8),
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
                      _buildNavBarItem(
                          'assets/images/Iconos/Icon_barra/user_icon.png', 0),
                      _buildNavBarItem(
                          'assets/images/Iconos/Icon_barra/Map_icon.png', 1),
                      _buildNavBarItem(
                          'assets/images/Iconos/Icon_barra/Biblioteca_icon.png', 2),
                      _buildNavBarItem(
                          'assets/images/Iconos/Icon_barra/Ajustes_icon.png', 3),
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

  Widget _buildTopHeader(
      String nickname, String? avatarUrl, int streak, int lives) {
    final bool isAdmin = _userProfile?['role'] == 'admin';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5),
              child: Container(
                width: 48,
                height: 48,
                color: Colors.white.withAlpha(200),
                child: avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: Colors.black87, size: 28),
                      )
                    : const Icon(Icons.person, color: Colors.black87, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderBadge(
            value: '$streak',
            label: 'racha',
            badgeColor: Colors.white.withAlpha(230),
            accentColor: Colors.orange.shade800,
            icon: Icons.local_fire_department,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showLivesInfoModal,
            onLongPress: () {
              if (isAdmin) {
                _showAdminRestoreLivesDialog();
              }
            },
            child: _buildHeaderBadge(
              value: '$lives',
              label: 'vidas',
              badgeColor: Colors.white.withAlpha(230),
              accentColor: Colors.redAccent,
              icon: Icons.favorite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required String value,
    required String label,
    required Color badgeColor,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 2),
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(String assetPath, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavBarTap(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white, width: 1.5)
              : null,
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

  Widget _buildLevelPath(
      double mapHeight, BuildContext context, List<_PathNode> pathNodes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = pathNodes
            .map((n) =>
                Offset(n.position.dx * width, n.position.dy * mapHeight))
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

  List<Widget> _buildNodeWithShadow(
      _PathNode node, Offset center, BuildContext context) {
    const nodeSize = 85.0;

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

  Widget _buildLevelNode(
      {required _PathNode node,
      required double size,
      required BuildContext context}) {
    final bool isAdmin = _userProfile?['role'] == 'admin';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        if (!node.isUnlocked) {
          _showAdminBypassDialog(context, node);
        }
      },
      onTap: () async {
        if (!node.isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAdmin
                  ? "🔒 Bloqueado (Mantén presionado para desbloquear como Admin)"
                  : "🔒 Debes completar el nivel anterior para desbloquear este"),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        if (_currentLives <= 0) {
          _showNoLivesDialog();
          return;
        }

        _launchLevel(node);
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
                          return const Icon(Icons.menu_book,
                              color: Colors.white, size: 30);
                        },
                      )
                    : const Icon(Icons.lock, color: Colors.white, size: 32),
              ),
            ),
            if (node.number != null)
              Positioned(
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        const segmentLength = 9.0;
        final end = min(distance + segmentLength, metric.length);
        if (draw) canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) =>
      oldDelegate.points != points;
}