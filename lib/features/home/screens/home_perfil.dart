import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/home_biblioteca.dart';
import 'package:nicalingo/features/home/screens/home_settings.dart';

class HomePerfilScreen extends StatefulWidget {
  const HomePerfilScreen({super.key});

  @override
  State<HomePerfilScreen> createState() => _HomePerfilScreenState();
}

class _HomePerfilScreenState extends State<HomePerfilScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  int _userLevel = 1;
  int _completedAchievementsCount = 0;
  final int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileData = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        int calculatedLevel = 1;
        try {
          final progressData = await supabase
              .from('user_progress')
              .select('current_level_id, level_id, is_completed')
              .eq('user_id', user.id);

          int maxLevel = 1;
          for (var item in progressData) {
            final isDone = item['is_completed'] == true ||
                item['is_completed'] == 'true' ||
                item['is_completed'] == 1;

            if (isDone) {
              final curr = int.tryParse(item['current_level_id']?.toString() ?? '');
              final lvl = int.tryParse(item['level_id']?.toString() ?? '');
              if (curr != null && curr > maxLevel) maxLevel = curr;
              if (lvl != null && lvl > maxLevel) maxLevel = lvl;
            }
          }
          calculatedLevel = maxLevel;
        } catch (e) {
          debugPrint('Aviso al calcular nivel: $e');
        }

        int achievements = 0;
        try {
          final achievementsResponse = await supabase
              .from('user_achievements')
              .select('id')
              .eq('user_id', user.id);
          achievements = (achievementsResponse as List).length;
        } catch (_) {}

        if (mounted) {
          setState(() {
            _userData = profileData;
            _userLevel = calculatedLevel;
            _completedAchievementsCount = achievements;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    }
  }

  void _editNickname() {
    final TextEditingController controller =
        TextEditingController(text: _userData?['nickname'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar apodo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Escribe tu nuevo apodo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow),
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                Navigator.pop(context);
                await _updateProfileField('nickname', newNickname);
              }
            },
            child:
                const Text('Guardar', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 75,
      );

      if (image == null) return;

      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName =
          '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      await supabase.storage.from('profiles').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl =
          supabase.storage.from('profiles').getPublicUrl(filePath);

      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl}).eq('id', user.id);

      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Foto de perfil actualizada con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e')),
        );
      }
    }
  }

  Future<void> _updateProfileField(String field, dynamic value) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      await supabase
          .from('profiles')
          .update({field: value}).eq('id', user.id);

      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil actualizado con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  void _onNavBarTap(int index) {
    if (index == _currentIndex) return;

    if (index == 1) {
      Navigator.pop(context);
      return;
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeBibliotecaScreen(),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final nickname = _userData?['nickname'] ?? (_isLoading ? 'Cargando...' : 'Sin apodo');
    final email = _userData?['email'] ?? (_isLoading ? '' : 'Sin correo');
    final streak = _userData?['streak'] ?? 0;
    final avatarUrl = _userData?['avatar_url'];

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
            child: RefreshIndicator(
              color: Colors.black87,
              backgroundColor: AppColors.primaryYellow,
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 10),
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
                        "Perfil personal",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[400],
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: _isLoading && avatarUrl == null
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : (avatarUrl == null
                                    ? const Icon(Icons.person,
                                        size: 60, color: Colors.white)
                                    : null),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 18, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editNickname,
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 20),
                    
                    // Tarjeta de estadísticas con el estilo unificado pero conservando los colores de sus elementos
                    _buildSectionCard(
                      title: "Estadísticas",
                      items: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(Icons.local_fire_department, 'Racha', '$streak'),
                              _buildStatItem(Icons.star, 'Logros', '$_completedAchievementsCount'),
                              _buildStatItem(Icons.bar_chart, 'Nivel', '$_userLevel'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mis logros',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                          3, (index) => _buildAchievementPlaceholder()),
                    ),
                    const SizedBox(height: 20),
                    
                    // Tarjeta del menú de opciones idéntica a settings
                    _buildSectionCard(
                      title: "Opciones de cuenta",
                      items: [
                        _buildRowItem(
                          icon: Icons.person_outline,
                          label: "Información personal",
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildRowItem(
                          icon: Icons.notifications_none,
                          label: "Notificaciones",
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildRowItem(
                          icon: Icons.privacy_tip_outlined,
                          label: "Privacidad",
                          onTap: () {},
                        ),
                        _buildDivider(),
                        _buildRowItem(
                          icon: Icons.info_outline,
                          label: "Información",
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Barra inferior unificada con Liquid Glass amarillo, borde brillante y efecto 3D
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

  // Conserva los colores originales de los iconos (amber) y textos oscuros dentro de las estadísticas
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.amber[800], size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white, // Blanco para que resalte sobre el fondo de la tarjeta
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementPlaceholder() {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            color: Colors.amber[300],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_border, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 6),
        const Text('---',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B86C4).withAlpha(160),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1E3A8A)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.white.withAlpha(40),
    );
  }
}