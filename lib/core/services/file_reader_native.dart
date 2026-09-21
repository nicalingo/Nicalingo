import 'dart:io';
import 'dart:typed_data';

/// Implementación nativa que lee y elimina el archivo WAV.
/// Al estar aislado, el compilador web nunca verá este archivo.
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