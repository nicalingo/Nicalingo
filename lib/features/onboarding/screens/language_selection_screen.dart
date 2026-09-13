import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/auth/screens/profile_capture_screen.dart';
import 'package:nicalingo/features/auth/screens/register_screen.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final SignupFlowModel? signupData;

  const LanguageSelectionScreen({super.key, this.signupData});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;
  int? _selectedLanguageId;
  bool _isLoading = false;

  final List<String> _languages = [
    'Miskito',
    'Garífuna',
    'Criollo',
    'Mayagna',
    'Rama',
    'Ulwa',
  ];

  void _showDevelopmentCardAlert(String languageName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/coco_ups.png',
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                '¡Idioma en Desarrollo!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Noot',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'El curso de $languageName aún no está disponible. Nuestro equipo está trabajando con la comunidad para traerlo muy pronto. (つ╥﹏╥)つ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
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
      ),
    );
  }

  Future<void> _checkLanguageStatus(String language) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('languages')
          .select('id, is_active')
          .eq('name', language)
          .maybeSingle();

      if (!mounted) return;

      final bool isAvailable = response != null && (response['is_active'] == true);

      if (isAvailable) {
        setState(() {
          _selectedLanguage = language;
          _selectedLanguageId = response['id'];
        });
      } else {
        _showDevelopmentCardAlert(language);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar disponibilidad: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedLanguage == null || _selectedLanguageId == null) return;

    if (widget.signupData != null) {
      widget.signupData!.languageId = _selectedLanguageId.toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterScreen(
            signupData: widget.signupData!,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw 'No hay un usuario autenticado.';
      }

      final levelResponse = await supabase
          .from('levels')
          .select('id')
          .eq('language_id', _selectedLanguageId!)
          .eq('level_number', 1)
          .single();

      final int levelId = levelResponse['id'];

      await supabase.from('user_progress').upsert({
        'user_id': user.id,
        'language_id': _selectedLanguageId,
        'current_level_id': levelId,
        'last_activity': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeMapScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el progreso: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  '¿Qué idioma quieres aprender?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: size.height * 0.22,
                child: Image.asset(
                  'assets/images/coco_señalando.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ListView.builder(
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final language = _languages[index];
                      final isSelected = _selectedLanguage == language;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: _isLoading ? null : () => _checkLanguageStatus(language),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE0F7FA) : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: isSelected 
                                  ? Border.all(color: const Color(0xFF34B3E4), width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              language,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF0288D1) : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: size.width * 0.55,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34B3E4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: (_selectedLanguage == null || _isLoading)
                        ? null 
                        : _handleContinue,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continuar',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}