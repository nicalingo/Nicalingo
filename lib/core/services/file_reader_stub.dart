import 'dart:typed_data';

/// Fallback para compilación estricta
Future<String> getRecordingTempPath() async {
  throw UnsupportedError('No se puede usar getRecordingTempPath directamente');
}

/// Interfaz para la compilación condicional
Future<Uint8List?> readAndClearFileBytes(String path) async {
  throw UnsupportedError('No se puede usar readAndClearFileBytes directamente');
}