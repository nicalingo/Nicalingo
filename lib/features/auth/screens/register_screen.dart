import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/auth/models/signup_flow_model.dart';

class RegisterScreen extends StatefulWidget {
  final SignupFlowModel signupData;

  const RegisterScreen({super.key, required this.signupData});

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
    _emailController.text = widget.signupData.email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final emailText = widget.signupData.email;
        final passwordText = _passwordController.text.trim();
        final supabase = Supabase.instance.client;

        final AuthResponse authResponse = await supabase.auth.signUp(
          email: emailText,
          password: passwordText,
        );

        final user = authResponse.user;

        if (user != null) {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'email': emailText,
            'nickname': widget.signupData.nickname,
            'avatar_url': widget.signupData.avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          });

          if (widget.signupData.languageId != null) {
            final int? langId = int.tryParse(widget.signupData.languageId!);

            if (langId != null) {
              final levelResponse = await supabase
                  .from('levels')
                  .select('id')
                  .eq('language_id', langId)
                  .eq('level_number', 1)
                  .maybeSingle();

              final int? levelId = levelResponse != null ? levelResponse['id'] as int? : null;

              await supabase.from('user_progress').upsert({
                'user_id': user.id,
                'language_id': langId,
                'current_level_id': levelId,
                'last_activity': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_email', emailText);
        await prefs.setString('temp_password', passwordText);

        if (!mounted) return;
        Navigator.pop(context);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('¡Verifica tu correo!'),
            content: Text(
              'Hemos enviado un enlace de confirmación a:\n\n$emailText\n\nPor favor, ve a tu correo, confirma tu cuenta y luego regresa a abrir la aplicación.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);

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
      backgroundColor: AppColors.primaryBlue, 
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
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
                            'assets/images/coco_espada.png',
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
              Expanded(
                flex: 11,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 30.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildRoundedInputField(
                            controller: _emailController,
                            hintText: 'correoelectronico@gmail.com',
                            enabled: false,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Ingresa tu correo';
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
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

  Widget _buildRoundedInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    bool enabled = true,
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
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black87, fontFamily: 'Inter', fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Inter'),
          fillColor: Colors.white,
          filled: true,
          suffixIcon: suffixIcon,
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