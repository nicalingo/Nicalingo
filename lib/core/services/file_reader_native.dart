import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Obtiene la ruta temporal en sistemas de archivos nativos (Android, Windows, etc.)
Future<String> getRecordingTempPath() async {
  final tempDir = await getTemporaryDirectory();
  return '${tempDir.path}/user_speech_${DateTime.now().millisecondsSinceEpoch}.wav';
}

/// Implementación nativa que lee y elimina el archivo WAV.
Future<Uint8List?> readAndClearFileBytes(String path) async {
  final file = File(path);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}
    return bytes;
  }
  return null;
}