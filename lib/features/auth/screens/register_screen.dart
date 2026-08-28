import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/onboarding/screens/language_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String email;

  const RegisterScreen({super.key, required this.email});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptTerms = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Función para registrarse en Supabase
  Future<void> _handleSignUp() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Registro en Supabase Auth
        // Gracias a trigger SQL, esto creará automáticamente el registro en public.profiles[cite: 6]
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;
        // Cerrar indicador de carga
        Navigator.pop(context);

        if (!mounted) return;
        // Navegar hacia la selección de idioma al completarse el registro[cite: 6]
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LanguageSelectionScreen(),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        // Cerrar indicador de carga
        Navigator.pop(context);

        if (!mounted) return;
        // Mostrar error devuelto por Supabase[cite: 6]
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrarse: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue, // Fondo azul para la parte superior[cite: 6]
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
              // Parte superior: Personaje con espada y texto
              Expanded(
                flex: 8,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 15.0, left: 20.0, right: 20.0),
                          child: Image.asset(
                            'assets/images/coco_espada.png', // Tu asset corregido[cite: 6]
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Termina de registrarte',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),

              // Parte inferior: Contenedor Amarillo con bordes redondeados tipo carta
              Expanded(
                flex: 11,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(55), // Curva pronunciada del Figma[cite: 6]
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 30.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // 1. Campo Correo electrónico
                          _buildRoundedInputField(
                            controller: _emailController,
                            hintText: 'correoelectronico@gmail.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Ingresa tu correo';
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // 2. Campo Contraseña (Con botón de ojito)
                          _buildRoundedInputField(
                            controller: _passwordController,
                            hintText: 'contraseña1234*',
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // 3. Campo Confirmar Contraseña (Con botón de ojito independiente)
                          _buildRoundedInputField(
                            controller: _confirmPasswordController,
                            hintText: 'contraseña1234*',
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Checkbox de Términos y Condiciones
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptTerms,
                                  activeColor: AppColors.primaryBlue,
                                  side: const BorderSide(color: Colors.black54, width: 1.5),
                                  onChanged: (value) {
                                    setState(() {
                                      _acceptTerms = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Acepto todos los terminos y condiciones de Sinskira (Nicalingo).',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Botón Registrarme Celeste
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
                                  backgroundColor: const Color(0xFF34B3E4), // Celeste del login[cite: 6]
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                                onPressed: _handleSignUp,
                                child: const Text(
                                  'Registrarme',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper optimizado y corregido para los Inputs de Texto
  Widget _buildRoundedInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textAlign: TextAlign.center, // Texto centrado[cite: 6]
        style: const TextStyle(color: Colors.black87, fontFamily: 'Inter', fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Inter'),
          fillColor: Colors.white,
          filled: true,
          suffixIcon: suffixIcon,
          // Crea un contrapeso invisible en el lado izquierdo para que el texto siga centrado al llevar ojito[cite: 6]
          prefixIcon: suffixIcon != null 
              ? const Visibility(
                  visible: false, 
                  maintainSize: true, 
                  maintainAnimation: true, 
                  maintainState: true,
                  child: Icon(Icons.visibility),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }
}