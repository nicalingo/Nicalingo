import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/home_perfil.dart';
import 'package:nicalingo/features/home/screens/home_biblioteca.dart';
import 'package:nicalingo/features/auth/screens/login_screen.dart';

class HomeSettingsScreen extends StatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  State<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends State<HomeSettingsScreen> {
  final int _currentIndex = 3;
  bool _soundEnabled = true;

  void _onNavBarTap(int index) {
    if (index == _currentIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePerfilScreen()),
      );
      return;
    }

    if (index == 1) {
      Navigator.pop(context);
      return;
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeBibliotecaScreen()),
      );
      return;
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Cambiar contraseña",
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: "Contraseña actual",
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setDialogState(() => obscureCurrent = !obscureCurrent);
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Ingresa tu contraseña actual";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: "Nueva contraseña",
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setDialogState(() => obscureNew = !obscureNew);
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Ingresa la nueva contraseña";
                          }
                          if (value.trim().length < 6) {
                            return "Mínimo 6 caracteres";
                          }
                          if (value.trim() == currentPasswordController.text.trim()) {
                            return "Debe ser diferente a la actual";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: "Confirmar nueva contraseña",
                          prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setDialogState(() => obscureConfirm = !obscureConfirm);
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return "Las contraseñas no coinciden";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.black54)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          final currentPassword = currentPasswordController.text.trim();
                          final newPassword = newPasswordController.text.trim();
                          final email = Supabase.instance.client.auth.currentUser?.email;

                          if (email == null) {
                            setDialogState(() {
                              dialogError = "No se encontró sesión activa.";
                            });
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isLoading = true;
                            dialogError = null;
                          });

                          try {
                            await Supabase.instance.client.auth.signInWithPassword(
                              email: email,
                              password: currentPassword,
                            );

                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: newPassword),
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('¡Contraseña actualizada con éxito!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } on AuthException catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              if (e.message.toLowerCase().contains("invalid login credentials")) {
                                dialogError = "La contraseña actual es incorrecta.";
                              } else {
                                dialogError = e.message;
                              }
                            });
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              dialogError = "Error al actualizar: $e";
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Guardar",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Cerrar sesión",
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "¿Estás seguro de que deseas cerrar sesión?",
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE64638),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Salir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      try {
        await Supabase.instance.client.auth.signOut();

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Ajustes",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección: Cuenta
                  _buildSectionCard(
                    title: "Cuenta",
                    items: [
                      _buildRowItem(
                        icon: Icons.person_outline,
                        label: "Información personal",
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildRowItem(
                        icon: Icons.lock_outline,
                        label: "Cambiar contraseña",
                        onTap: _changePassword,
                      ),
                      _buildDivider(),
                      _buildRowItem(
                        icon: Icons.mail_outline,
                        label: "Correo electrónico",
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
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Sección: Preferencias
                  _buildSectionCard(
                    title: "Preferencias",
                    items: [
                      _buildRowItem(
                        icon: Icons.language,
                        label: "Idioma",
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSwitchItem(
                        icon: Icons.volume_up_outlined,
                        label: "Sonido",
                        value: _soundEnabled,
                        onChanged: (val) {
                          setState(() => _soundEnabled = val);
                        },
                      ),
                      _buildDivider(),
                      _buildRowItem(
                        icon: Icons.text_fields,
                        label: "Tamaño de texto",
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Sección: Soporte
                  _buildSectionCard(
                    title: "Soporte",
                    items: [
                      _buildRowItem(
                        icon: Icons.help_outline,
                        label: "Centro de Ayuda",
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildRowItem(
                        icon: Icons.chat_bubble_outline,
                        label: "Envíanos tu opinión",
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildRowItem(
                        icon: Icons.info_outline,
                        label: "Acerca de la app",
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // Botón Cerrar Sesión
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE64638),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Cerrar sesión",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
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

  Widget _buildSwitchItem({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
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
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF1E3A8A),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade400,
            ),
          ),
        ],
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

  Widget _buildNavBarItem(String assetPath, int index) {
    bool isSelected = _currentIndex == index;
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