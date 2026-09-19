import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String repoOwner = 'nicalingo';
  static const String repoName = 'Nicalingo';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Obtener la versión local instalada
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Consultar el último release publicado en GitHub
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String latestTag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final List assets = data['assets'] as List? ?? [];

      // 3. Buscar el enlace directo de descarga del APK
      String? apkDownloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      // 4. Comparar versiones
      if (latestTag.isNotEmpty && _isNewerVersion(currentVersion, latestTag)) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestTag, apkDownloadUrl);
      }
    } catch (e) {
      debugPrint('Error al comprobar actualizaciones: $e');
    }
  }

  static bool _isNewerVersion(String currentVersion, String targetVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final targetParts = targetVersion.split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
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
    String? apkUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('¡Actualización disponible!'),
          content: Text(
            'Hay una nueva versión de NicaLingo ($newVersion). Descárgala para disfrutar de las últimas mejoras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (apkUrl != null) {
                  final uri = Uri.parse(apkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }
}