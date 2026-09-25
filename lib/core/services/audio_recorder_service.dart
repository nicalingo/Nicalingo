import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

// Importación condicional:
// Carga file_reader_web.dart en Web y file_reader_native.dart en Android/Windows.
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

      // En Web se pasa cadena vacía (el plugin maneja un Blob en memoria).
      // En móvil/escritorio se obtiene el path temporal aislado de path_provider.
      final String path = kIsWeb ? '' : await getRecordingTempPath();

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
        // En Android/Windows, lee y elimina el archivo físico
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