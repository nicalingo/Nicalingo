import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// ¡ESTE ES EL CAMBIO CLAVE! Usar el paquete universal_io en lugar de dart:io o condicionales
import 'package:universal_io/io.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Verifica o solicita permisos de grabación
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint("Error verificando permisos de micrófono: $e");
      return false;
    }
  }

  /// Inicia la grabación en formato WAV 16kHz mono (ideal para análisis fonético)
  Future<void> startRecording() async {
    try {
      if (!await hasPermission()) return;

      String path = '';

      // En móvil y Windows guardamos en un archivo temporal
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/user_speech_${DateTime.now().millisecondsSinceEpoch}.wav';
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );
    } catch (e) {
      debugPrint("Error al iniciar grabación: $e");
    }
  }

  /// Detiene la grabación y retorna los bytes del audio grabado
  Future<Uint8List?> stopRecording() async {
    try {
      final String? path = await _recorder.stop();
      if (path == null) return null;

      if (kIsWeb) {
        // En Web, 'path' es una URL Blob temporal (blob:http...)
        final response = await http.get(Uri.parse(path));
        return response.bodyBytes;
      } else {
        // En Android y Windows usamos File de universal_io
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            await file.delete();
          } catch (_) {}
          return bytes;
        }
      }
    } catch (e) {
      debugPrint("Error al detener grabación: $e");
    }
    return null;
  }

  /// Descarga en memoria los bytes del audio nativo almacenado en Supabase
  Future<Uint8List?> fetchAudioBytes(String audioUrl) async {
    try {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint("Error descargando audio nativo: HTTP ${response.statusCode}");
    } catch (e) {
      debugPrint("Excepción descargando audio nativo: $e");
    }
    return null;
  }

  /// Libera recursos del grabador
  void dispose() {
    _recorder.dispose();
  }
}