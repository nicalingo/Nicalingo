import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';
import 'package:nicalingo/features/levels/screens/loading_level_screen.dart';

enum _NodeType { level, star }

class _PathNode {
  final String id;
  final _NodeType type;
  final Offset position; 
  final String? number;
  final String? iconPath;
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
            Positioned(
              top: 10,
              right: -30,
              child: Transform.rotate(
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
                'assets/images/coco_bandera.png',
                width: 140,
                height: 200,
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
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
                  SizedBox(
                    height: mapHeight,
                    child: _buildLevelPath(mapHeight, context), 
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelPath(double mapHeight, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = _pathNodes
            .map((n) => Offset(n.position.dx * width, n.position.dy * mapHeight))
            .toList();

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedPathPainter(points: centers),
              ),
            ),
            for (int i = 0; i < _pathNodes.length; i++)
              ..._buildNodeWithShadow(_pathNodes[i], centers[i], context),
          ],
        );
      },
    );
  }

  List<Widget> _buildNodeWithShadow(_PathNode node, Offset center, BuildContext context) {
    final nodeSize = node.type == _NodeType.star ? 54.0 : 85.0;

    return [
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
      Positioned(
        left: center.dx - nodeSize / 2,
        top: center.dy - nodeSize / 2,
        child: _buildLevelNode(node: node, size: nodeSize, context: context),
      ),
    ];
  }

  Widget _buildLevelNode({required _PathNode node, required double size, required BuildContext context}) {
    return GestureDetector(
      onTap: () {
        String loadingTitle = node.type == _NodeType.star 
            ? "Cargando desafío especial..." 
            : "Cargando Nivel ${node.number ?? ''}...";

        int levelNumber = int.tryParse(node.number ?? '1') ?? 1;
        int languageId = 1; 

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingLevelScreen(
              languageId: languageId,
              levelNumber: levelNumber,
              levelTitle: loadingTitle,
            ),
          ),
        );
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
      final midY = current.dy + (next.dy - current.dy) / 2;
      path.cubicTo(current.dx, midY, next.dx, midY, next.dx, next.dy);
    }
    final paint = Paint()
      ..color = Colors.white.withAlpha(130)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? 9.0 : 9.0;
        final end = min(distance + segmentLength, metric.length);
        if (draw) canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter oldDelegate) => oldDelegate.points != points;
}