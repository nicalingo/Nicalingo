import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
              // Parte superior: Fondo Amarillo, Texto de Bienvenida y Personaje
              Expanded(
                flex: 5,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: Text(
                          'BIENVENIDO',
                          style: TextStyle(
                            fontFamily: 'Noot',
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // Contenedor del personaje coco_feliz
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Image.asset(
                            'assets/images/coco_feliz.png',
                            fit: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Parte inferior: Sección Azul con curva suave
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    // Fondo azul estilizado con un ClipPath para emular la ola
                    ClipPath(
                      clipper: WaveClipper(),
                      child: Container(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    // Contenido del Formulario de Registro
                    Padding(
                      padding: const EdgeInsets.only(top: 60.0, left: 40.0, right: 40.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              'Registrate:',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                            ),
                            const SizedBox(height: 25),
                            // Campo de Texto de Correo Electrónico
                            TextFormField(
                              controller: _emailController,
                              style: AppTextStyles.inputTextStyle,
                              decoration: InputDecoration(
                                hintText: 'Correo electronico',
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Inter',
                                ),
                                fillColor: const Color(0xFFE0E0E0),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(0), // Rectangular como en tu diseño
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu correo';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Ingresa un correo electrónico válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'or',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                color: AppColors.textWhite,
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Botones de Redes Sociales (Google & Facebook)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Aquí puedes meter logos temporales o contenedores con color
                                Container(
                                  width: 45,
                                  height: 45,
                                  color: const Color(0xFF1877F2), // Color base Facebook
                                  child: const Icon(Icons.facebook, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  width: 45,
                                  height: 45,
                                  color: Colors.white,
                                  child: const Icon(Icons.g_mobiledata, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Enlace inferior para iniciar sesión
                            TextButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  // Lógica de registro preliminar
                                }
                              },
                              child: const Text(
                                '¿Ya tienes cuenta? inicia sesión',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppColors.textWhite,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dibujador personalizado para lograr la onda que divide las dos secciones
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 40); // Ajuste inicial del corte

    var firstControlPoint = Offset(size.width / 4, 0);
    var firstEndPoint = Offset(size.width / 2, 20);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width - (size.width / 4), 40);
    var secondEndPoint = Offset(size.width, 10);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}