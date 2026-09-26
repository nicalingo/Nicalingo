import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String repoOwner = 'nicalingo';
  static const String repoName = 'Nicalingo';

  static Future<void> checkForUpdates(BuildContext context) async {
    // 1. En la Web nunca se debe pedir actualizar una app instalada
    if (kIsWeb) return;

    try {
      // 2. Obtener la versión local instalada
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 3. Consultar el último release publicado en GitHub con timeout y headers
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'NicaLingo-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String latestTag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final List assets = data['assets'] as List? ?? [];

      // 4. Buscar el binario correspondiente a la plataforma del dispositivo
      String? downloadUrl;
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final isWindows = defaultTargetPlatform == TargetPlatform.windows;

      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (isAndroid && name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        } else if (isWindows && name.endsWith('.zip')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      // Si no encuentra el archivo directo, usar la página de la release como respaldo
      downloadUrl ??= data['html_url'] as String?;

      // 5. Comparar versiones y mostrar diálogo
      if (latestTag.isNotEmpty && _isNewerVersion(currentVersion, latestTag)) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestTag, downloadUrl);
      }
    } catch (e) {
      debugPrint('Error al comprobar actualizaciones: $e');
    }
  }

  static bool _isNewerVersion(String currentVersion, String targetVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final targetParts = targetVersion.split('.').map(int.parse).toList();

      final length = currentParts.length > targetParts.length
          ? currentParts.length
          : targetParts.length;

      for (var i = 0; i < length; i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final target = i < targetParts.length ? targetParts[i] : 0;
        if (target > current) return true;
        if (target < current) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String? downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('¡Actualización disponible!'),
          content: Text(
            'Hay una nueva versión de NicaLingo ($newVersion). Descárgala para disfrutar de las últimas mejoras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (downloadUrl != null) {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}