import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// Importación condicional MÁGICA:
// El compilador carga file_reader_web.dart si compila para JS/Web,
// y file_reader_native.dart si compila para Android/Windows.
import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_native.dart'
    if (dart.library.js_interop) 'file_reader_web.dart';

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
        // En Web, descargamos el Blob generado en memoria
        final response = await http.get(Uri.parse(path));
        return response.bodyBytes;
      } else {
        // En Android/Windows, la magia condicional lee el File real
        return await readAndClearFileBytes(path);
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