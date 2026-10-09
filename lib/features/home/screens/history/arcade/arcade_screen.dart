import 'package:flutter/material.dart';
import 'package:nicalingo/core/theme/app_colors.dart';

class ArcadeScreen extends StatelessWidget {
  final String? currentLanguageCode;

  const ArcadeScreen({super.key, this.currentLanguageCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.primaryYellow,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryYellow,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.textWhite, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text(
            'Zona Arcade',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Iconos/background/home_back.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.74,
                children: [
                  _buildGameCard(
                    title: "Atrapa con Coco",
                    tag: "Refuerzo",
                    imageAsset: "assets/images/arcade/icononos/come_coco.jpeg",
                    cardColor: const Color(0xFFFFD180),
                    isEnabled: true,
                    actionText: "Jugar",
                    onTap: () {
                    },
                  ),
                  _buildGameCard(
                    title: "Memoria Ancestral",
                    tag: "Cartas",
                    icon: Icons.style_rounded,
                    cardColor: const Color(0xFF80D8FF),
                    isEnabled: true,
                    actionText: "Jugar",
                    onTap: () {
                    },
                  ),
                  _buildGameCard(
                    title: "Trivia Cultural",
                    tag: "Multijugador",
                    icon: Icons.psychology_alt_rounded,
                    cardColor: const Color(0xFFA7FFEB),
                    isEnabled: true,
                    actionText: "Jugar",
                    onTap: () {

                    },
                  ),
                  _buildGameCard(
                    title: "Repite con Coco",
                    tag: "Voz / Habla",
                    icon: Icons.record_voice_over_rounded,
                    cardColor: const Color(0xFFD1C4E9),
                    isEnabled: false,
                    actionText: "Jugar",
                    onTap: () {
                    },
                  ),
                  _buildGameCard(
                    title: "Diccionario Coco",
                    tag: "Consulta",
                    icon: Icons.auto_stories_rounded,
                    cardColor: const Color(0xFFFFE082),
                    isEnabled: true,
                    actionText: "Abrir",
                    onTap: () {
                    },
                  ),
                  _buildGameCard(
                    title: "LingoClip",
                    tag: "Canciones",
                    icon: Icons.music_note_rounded,
                    cardColor: const Color(0xFFFF80AB),
                    isEnabled: false,
                    actionText: "Jugar",
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String tag,
    String? imageAsset,
    IconData? icon,
    required Color cardColor,
    required bool isEnabled,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withAlpha(230),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: imageAsset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        imageAsset,
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.sports_esports_rounded,
                          size: 54,
                          color: Colors.black87.withAlpha(180),
                        ),
                      ),
                    )
                  : Icon(
                      icon ?? Icons.sports_esports_rounded,
                      size: 54,
                      color: Colors.black87.withAlpha(180),
                    ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: isEnabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? const Color(0xFFFF9100) : Colors.grey.shade400,
                foregroundColor: Colors.white,
                elevation: isEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEnabled ? actionText : 'Pronto',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}