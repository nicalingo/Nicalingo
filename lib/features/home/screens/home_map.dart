import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class HomeMapScreen extends StatelessWidget {
  const HomeMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B), // Azul oscuro de fondo
      body: SafeArea(
        child: Stack(
          children: [
            // Contenido principal con scroll para el mapa de niveles y caminitos
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  
                  // 1. Tarjeta flotante superior ("Primeras palabras")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Primeras palabras',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: size.height * 0.04),

                  // --- NIVEL 1 (Izquierda) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 45.0),
                      child: _buildLevelNode(
                        levelNumber: '1',
                        color: const Color(0xFF34B3E4),
                        iconPath: 'assets/images/Iconos/Icon_niveles/conectores_lv1.png',
                        onTap: () {},
                      ),
                    ),
                  ),

                  // Caminito punteado de Nivel 1 a Nivel 2
                  _buildDottedPathCurve(isGoingRight: true),

                  // --- NIVEL 2 (Derecha) ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 55.0),
                      child: _buildLevelNode(
                        levelNumber: '2',
                        color: const Color(0xFF0055FF),
                        iconPath: 'assets/images/Iconos/Icon_niveles/familia_lv2.png',
                        onTap: () {},
                      ),
                    ),
                  ),

                  // Caminito punteado de Nivel 2 a Nivel 3
                  _buildDottedPathCurve(isGoingRight: false),

                  // --- NIVEL 3 (Izquierda) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 55.0),
                      child: _buildLevelNode(
                        levelNumber: '3',
                        color: const Color(0xFFFF6622),
                        iconPath: 'assets/images/Iconos/Icon_niveles/pronombres_lv3.png',
                        onTap: () {},
                      ),
                    ),
                  ),

                  // Caminito punteado de Nivel 3 a Nivel 4
                  _buildDottedPathCurve(isGoingRight: true),

                  // --- NIVEL 4 (Derecha) ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 45.0),
                      child: _buildLevelNode(
                        levelNumber: '4',
                        color: const Color(0xFFFF9900),
                        iconPath: 'assets/images/Iconos/Icon_niveles/saludos_lv4.png',
                        onTap: () {},
                      ),
                    ),
                  ),

                  const SizedBox(height: 120), // Espacio para la barra inferior
                ],
              ),
            ),

            // 2. Barra de navegación inferior flotante con la ruta corregida (Icon_bar)
            Positioned(
              left: 20,
              right: 20,
              bottom: 15,
              child: Container(
                height: 65,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: IconButton(
                        icon: Image.asset('assets/images/Iconos/Icon_barra/user_icon.png'),
                        onPressed: () {},
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: Image.asset('assets/images/Iconos/Icon_barra/Map_icon.png'),
                        onPressed: () {},
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: Image.asset('assets/images/Iconos/Icon_barra/Biblioteca_icon.png'),
                        onPressed: () {},
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: Image.asset('assets/images/Iconos/Icon_barra/Ajustes_icon.png'),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para construir cada nodo de nivel
  Widget _buildLevelNode({
    required String levelNumber,
    required Color color,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Image.asset(
                  iconPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  levelNumber,
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

  // Widget para simular el caminito punteado en zigzag entre niveles
  Widget _buildDottedPathCurve({required bool isGoingRight}) {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(120),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}