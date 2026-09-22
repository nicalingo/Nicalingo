import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/auth/models/signup_flow_model.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';
import 'package:nicalingo/features/onboarding/screens/language_selection_screen.dart';

class ProfileCaptureScreen extends StatefulWidget {
  final SignupFlowModel? signupData;

  const ProfileCaptureScreen({super.key, this.signupData});

  @override
  State<ProfileCaptureScreen> createState() => _ProfileCaptureScreenState();
}

class _ProfileCaptureScreenState extends State<ProfileCaptureScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  void _loadInitialUserData() {
    if (widget.signupData?.fullName != null &&
        widget.signupData!.fullName!.isNotEmpty) {
      _fullNameController.text = widget.signupData!.fullName!;
    }
    if (widget.signupData?.nickname != null &&
        widget.signupData!.nickname!.isNotEmpty) {
      _nicknameController.text = widget.signupData!.nickname!;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metaName = user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          '';
      if (metaName.isNotEmpty && _fullNameController.text.isEmpty) {
        _fullNameController.text = metaName;
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryBlue),
                  title: const Text(
                    'Tomar foto con la cámara',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
                  title: const Text(
                    'Elegir de la galería',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Verifica en Supabase si el apodo ya existe
  Future<bool> _isNicknameAvailable(String nickname, String? currentUserId) async {
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .from('profiles')
          .select('id')
          .ilike('nickname', nickname.trim());

      if (currentUserId != null) {
        query = query.neq('id', currentUserId);
      }

      final List<dynamic> response = await query;
      return response.isEmpty;
    } catch (e) {
      debugPrint('Error al validar apodo: $e');
      return true;
    }
  }

  Future<void> _handleEntrar() async {
    final fullName = _fullNameController.text.trim();
    final nickname = _nicknameController.text.trim().toLowerCase();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresá tu nombre completo'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresá tu apodo'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (nickname.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El apodo no debe contener espacios'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // 1. Validar unicidad del apodo
      final isAvailable = await _isNicknameAvailable(nickname, user?.id);
      if (!isAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este apodo ya está en uso. Elige otro.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Subida de imagen al storage si existe
      String? avatarUrl;
      if (_imageFile != null && user != null) {
        try {
          final fileExt = _imageFile!.path.split('.').last;
          final fileName =
              '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage.from('avatars').upload(
                fileName,
                _imageFile!,
                fileOptions: const FileOptions(upsert: true),
              );

          avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
        } catch (uploadError) {
          debugPrint('Aviso de storage: $uploadError');
        }
      }

      // 3. Flujo onboarding / registro: hereda fullName y nickname
      if (widget.signupData != null) {
        final updatedSignupData = widget.signupData!.copyWith(
          fullName: fullName,
          nickname: nickname,
          avatarUrl: avatarUrl,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LanguageSelectionScreen(
              signupData: updatedSignupData,
            ),
          ),
        );
        return;
      }

      // 4. Guardado directo para usuarios ya logueados
      if (user != null) {
        final profileData = {
          'id': user.id,
          'full_name': fullName,
          'nickname': nickname,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (avatarUrl != null) {
          profileData['avatar_url'] = avatarUrl;
        }

        await supabase.from('profiles').upsert(profileData);
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error en guardado de perfil: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aviso: $e'),
          backgroundColor: Colors.orange[800],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                color: Colors.grey.shade500,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 15),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/coco saludo.png',
                    height: 90,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets, size: 70, color: AppColors.textDark);
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'NicaLingo',
                    style: TextStyle(
                      fontFamily: 'Noot',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Creá tu perfil',
                        style: TextStyle(
                          fontFamily: 'Noot',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Completá tus datos para empezar la aventura.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campo 1: Nombre Completo
                      _buildField(
                        controller: _fullNameController,
                        label: 'NOMBRE COMPLETO',
                        hint: 'Ej. Juan Pérez',
                      ),
                      const SizedBox(height: 16),

                      // Campo 2: Apodo (Único)
                      _buildField(
                        controller: _nicknameController,
                        label: 'TU APODO (ÚNICO)',
                        hint: 'Ej. juancho99',
                      ),
                      const SizedBox(height: 20),

                      // Campo 3: Foto de Perfil
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _pickImage(ImageSource.camera),
                            onLongPress: () => _pickImage(ImageSource.gallery),
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: AppColors.primaryYellow,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                image: _imageFile != null
                                    ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _imageFile == null
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          color: AppColors.primaryBlue,
                                          size: 26,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Tu foto',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tocá para abrir cámara o mantené apretado para galería.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.white70,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                GestureDetector(
                                  onTap: _showImageSourceDialog,
                                  child: const Text(
                                    'Opciones de foto',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryYellow,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Botón Continuar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleEntrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryYellow,
                            foregroundColor: AppColors.textDark,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textDark,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Continuar',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                        ),
                      ),
                    ],
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