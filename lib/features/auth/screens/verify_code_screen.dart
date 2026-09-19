import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/core/theme/app_text_styles.dart';
import 'package:nicalingo/features/auth/models/signup_flow_model.dart';
import 'package:nicalingo/features/auth/screens/splash/transition_splash_screen.dart';
import 'package:nicalingo/features/auth/screens/reset_password_screen.dart';
import 'package:nicalingo/features/home/screens/home_map.dart';

class VerifyCodeScreen extends StatefulWidget {
  final SignupFlowModel signupData;
  final bool isResetPassword;

  const VerifyCodeScreen({
    super.key,
    required this.signupData,
    this.isResetPassword = false,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final token = _codeController.text.trim();
    if (token.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el código de 8 dígitos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // ==========================================
      // CASO A: RECUPERACIÓN DE CONTRASEÑA
      // ==========================================
      if (widget.isResetPassword) {
        final recoveryResponse = await supabase.auth.verifyOTP(
          type: OtpType.recovery,
          token: token,
          email: widget.signupData.email,
        );

        if (recoveryResponse.session == null) {
          throw Exception('Código incorrecto o expirado.');
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        // Pasa a la pantalla de Figma con el saludo personalizado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              nickname: widget.signupData.nickname ?? '',
            ),
          ),
        );
        return;
      }

      // ==========================================
      // CASO B: REGISTRO NUEVO DE USUARIO
      // ==========================================
      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: widget.signupData.email,
      );

      if (response.session != null) {
        final user = response.user;

        if (user != null) {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'email': widget.signupData.email,
            'role': 'user',
            'nickname': widget.signupData.nickname,
            'avatar_url': widget.signupData.avatarUrl,
            'created_at': DateTime.now().toIso8601String(),
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
                'is_completed': false,
                'last_activity': DateTime.now().toIso8601String(),
              });
            }
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_verification');
          await prefs.remove('temp_email');
          await prefs.remove('temp_nickname');
          await prefs.remove('temp_avatar');
          await prefs.remove('temp_language');
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TransitionSplashScreen(
              message: '¡Bienvenido a NicaLingo!',
              imagePath: 'assets/images/coco_feliz.png',
              onNavigation: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeMapScreen(),
                  ),
                );
              },
            ),
          ),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    try {
      if (widget.isResetPassword) {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          widget.signupData.email,
        );
      } else {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: widget.signupData.email,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código reenviado. Revisa tu bandeja de entrada o Spam.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reenviar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryYellow,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Column(
            children: [
              Expanded(
                flex: 10,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isResetPassword)
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Confirmación de datos',
                        style: AppTextStyles.titleMediumNoot.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Image.asset(
                            'assets/images/coco saludo.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 11,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 25.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Enviaremos un código a tu correo\npara Confirmar tu identidad',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMediumInter.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textWhite,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _resendCode,
                              child: Text(
                                _isResending ? 'Enviando...' : 'Enviar código',
                                style: AppTextStyles.bodyMediumInter.copyWith(
                                  fontSize: 12,
                                  color: AppColors.secondarySkyBlue,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.secondarySkyBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '¿No lo encuentras? Revisa tu carpeta de Spam o Correo no deseado.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMediumInter.copyWith(
                                fontSize: 11,
                                color: AppColors.textWhite.withAlpha(200),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 8,
                            style: AppTextStyles.inputTextStyle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '00000000',
                              hintStyle: AppTextStyles.inputTextStyle.copyWith(
                                color: Colors.grey.shade400,
                                letterSpacing: 6,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: size.width * 0.5,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondarySkyBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: _isLoading ? null : _verifyOtp,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Continuar',
                                      style: AppTextStyles.bodyLargeInter.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
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
      ),
    );
  }
}