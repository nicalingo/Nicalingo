import 'dart:typed_data';

/// Implementación web que simplemente retorna null
/// porque en Web se lee el Blob de memoria con http.
Future<Uint8List?> readAndClearFileBytes(String path) async {
  return null;
}