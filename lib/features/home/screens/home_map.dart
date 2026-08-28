import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

/// Tipo de nodo dentro del camino.
enum _NodeType { level, star }

/// Datos de un nodo del camino (nivel numerado o estrella decorativa).
class _PathNode {
  final String id;
  final _NodeType type;
  final Offset position; // Relativa (0.0 - 1.0) dentro del área del mapa
  final String? number;
  final String? iconPath; // null para la estrella
  final Color color;
  final Color ringColor;

  const _PathNode({
    required this.id,
    required this.position,
    this.type = _NodeType.level,
    this.number,
    this.iconPath,
    this.color = Colors.white,
    this.ringColor = Colors.white,
  });
}

class HomeMapScreen extends StatelessWidget {
  const HomeMapScreen({super.key});

  // Nodos del camino, en el orden en que deben conectarse.
  // Ajusta `position` (fracciones de 0.0 a 1.0) para mover cada nodo.
  static const List<_PathNode> _pathNodes = [
    _PathNode(
      id: '1',
      position: Offset(0.26, 0.13),
      number: '1',
      iconPath: 'assets/images/Iconos/Icon_niveles/conectores_lv1.png',
      color: Color(0xFF34B3E4),
      ringColor: Color(0xFF8FE388),
    ),
    _PathNode(
      id: '2',
      position: Offset(0.74, 0.33),
      number: '2',
      iconPath: 'assets/images/Iconos/Icon_niveles/familia_lv2.png',
      color: Color(0xFF0055FF),
      ringColor: Colors.white,
    ),
    _PathNode(
      id: '3',
      position: Offset(0.25, 0.53),
      number: '3',
      iconPath: 'assets/images/Iconos/Icon_niveles/pronombres_lv3.png',
      color: Color(0xFFFF6622),
      ringColor: Colors.white,
    ),
    _PathNode(
      id: 'star',
      type: _NodeType.star,
      position: Offset(0.5, 0.61),
      color: Color(0xFF3E6BE0),
      ringColor: Colors.white,
    ),
    _PathNode(
      id: '4',
      position: Offset(0.74, 0.80),
      number: '4',
      iconPath: 'assets/images/Iconos/Icon_niveles/saludos_lv4.png',
      color: Color(0xFFFF9900),
      ringColor: Colors.white,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mapHeight = size.height * 0.72;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A6B),
      body: SafeArea(
        child: Stack(
          children: [
            // 0. Elementos decorativos de fondo (cocos en las esquinas)
            // Si tienes assets distintos para cada coco (uno con sombrero
            // de explorador arriba, otro con lentes y bandera abajo)
            // reemplaza cada ruta por la suya.
            Positioned(
              top: 10,
              right: -30,
              child: Transform.rotate(
                // OJO: `angle` es en RADIANES, no en grados.
                // 150 (como estaba) equivale a ~8595°, por eso se veía mal.
                // Un giro pequeño (~-20°) es lo que da el efecto de "asomando"
                // que se ve en la referencia. Ajusta el signo/valor a gusto.
                angle: -20 * pi / 180,
                child: Image.asset(
                  'assets/images/coco_bandera.png',
                  width: 130,
                  height: 150,
                ),
              ),
            ),

            Positioned(
              bottom: 55,
              left: -20,
              child: Image.asset(
                // Antes: 150x350 (muy estirado verticalmente) con left: 90
                // (empujado hacia adentro). Con proporciones normales y
                // pegado al borde izquierdo se ve como en la referencia.
                'assets/images/coco_bandera.png',
                width: 140,
                height: 200,
              ),
            ),

            // 1. Contenido principal con scroll
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Título superior
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white, width: 4),
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

                  SizedBox(height: size.height * 0.03),

                  // Mapa de niveles: camino curvo punteado + nodos + estrella
                  SizedBox(
                    height: mapHeight,
                    child: _buildLevelPath(mapHeight),
                  ),

                  const SizedBox(height: 110),
                ],
              ),
            ),

            // 2. Barra de navegación inferior flotante
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

  /// Construye el camino: calcula el centro real de cada nodo a partir de
  /// sus coordenadas relativas, dibuja la curva punteada que los conecta
  /// y coloca los nodos (y su sombra) encima.
  Widget _buildLevelPath(double mapHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final centers = _pathNodes
            .map((n) => Offset(n.position.dx * width, n.position.dy * mapHeight))
            .toList();

        return Stack(
          children: [
            // Camino curvo punteado detrás de los nodos
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedPathPainter(points: centers),
              ),
            ),

            // Nodos (con su sombra ovalada debajo)
            for (int i = 0; i < _pathNodes.length; i++)
              ..._buildNodeWithShadow(_pathNodes[i], centers[i]),
          ],
        );
      },
    );
  }

  List<Widget> _buildNodeWithShadow(_PathNode node, Offset center) {
    final nodeSize = node.type == _NodeType.star ? 54.0 : 85.0;

    return [
      // Sombra ovalada en el "piso"
      Positioned(
        left: center.dx - nodeSize * 0.4,
        top: center.dy + nodeSize / 2 - 8,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: nodeSize * 0.8,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ),
      // Nodo
      Positioned(
        left: center.dx - nodeSize / 2,
        top: center.dy - nodeSize / 2,
        child: _buildLevelNode(node: node, size: nodeSize),
      ),
    ];
  }

  // Widget auxiliar para construir cada nodo de nivel (o la estrella).
  Widget _buildLevelNode({required _PathNode node, required double size}) {
    return GestureDetector(
      onTap: () {
        // navegar al nivel `node.id`
      },
      child: SizedBox(
        width: size + 5,
        height: size + 15,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: node.color,
                shape: BoxShape.circle,
                border: Border.all(color: node.ringColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(node.type == _NodeType.star ? 10 : 11),
                child: node.type == _NodeType.star
                    ? const Icon(Icons.star_rounded, color: Color(0xFFFFC94A), size: 30)
                    : Image.asset(node.iconPath!, fit: BoxFit.contain),
              ),
            ),
            if (node.number != null)
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
                    node.number!,
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
}

/// Dibuja una curva suave y punteada que pasa por cada punto de [points].
class _DashedPathPainter extends CustomPainter {
  final List<Offset> points;
  const _DashedPathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      // Puntos de control alineados en X con cada extremo pero a la misma
      // altura intermedia: esto genera una curva en forma de "S" bien
      // marcada en vez de una diagonal casi recta.
      final midY = current.dy + (next.dy - current.dy) / 2;
      final control1 = Offset(current.dx, midY);
      final control2 = Offset(next.dx, midY);
      path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, next.dx, next.dy);
    }

    final paint = Paint()
      ..color = Colors.white.withAlpha(130)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, path, paint, dashWidth: 9, gapWidth: 9);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double gapWidth,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? dashWidth : gapWidth;
        final end = min(distance + segmentLength, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => oldDelegate.points != points;
}
