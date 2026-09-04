import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importante para usar Supabase
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  // Idioma seleccionado actualmente
  String? _selectedLanguage;

  // Estado de carga para evitar múltiples clics mientras guarda en la BD
  bool _isLoading = false;

  // Lista de los 6 idiomas indígenas y comunitarios de Nicaragua
  final List<String> _languages = [
    'Miskito',
    'Garífuna',
    'Criollo',
    'Mayagna',
    'Rama',
    'Ulwa',
  ];

  // Función para guardar el idioma seleccionado en Supabase
  Future<void> _saveSelectedLanguage() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw 'No hay un usuario autenticado.';
      }

      // 1. Obtener el 'id' del idioma seleccionado en la tabla 'languages'
      final languageResponse = await supabase
          .from('languages')
          .select('id')
          .eq('name', _selectedLanguage!)
          .single();

      final int languageId = languageResponse['id'];

      // 2. Obtener el 'id' del Nivel 1 correspondiente a ese idioma
      final levelResponse = await supabase
          .from('levels')
          .select('id')
          .eq('language_id', languageId)
          .eq('level_number', 1)
          .single();

      final int levelId = levelResponse['id'];

      // 3. Guardar o actualizar en 'user_progress' (maneja la clave compuesta user_id + language_id)
      await supabase.from('user_progress').upsert({
        'user_id': user.id,
        'language_id': languageId,
        'current_level_id': levelId,
        'last_activity': DateTime.now().toIso8601String(),
      });

      // 4. Si todo sale bien, navegar al mapa de niveles
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
      backgroundColor: AppColors.primaryYellow, // Fondo amarillo general
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
          child: Column(
            children: [
              // 1. Tarjeta flotante superior con la pregunta
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

              // 2. Imagen del Coco Señalando
              SizedBox(
                height: size.height * 0.22,
                child: Image.asset(
                  'assets/images/coco_señalando.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),

              // 3. Contenedor central con la lista de opciones de idiomas
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
                          onTap: _isLoading
                              ? null
                              : () {
                                  // Validación solicitada
                                  if (language == 'Miskito') {
                                    setState(() {
                                      _selectedLanguage = language;
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Estamos trabajando para expandir nuestra libreria de idiomas (つ╥﹏╥)つ',
                                        ),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
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

              // 4. Botón inferior "Continuar"
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
                        : _saveSelectedLanguage, // Llama a la función asíncrona de guardado
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