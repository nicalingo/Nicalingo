import 'dart:typed_data';

/// En la web no se requiere un path en disco; se usa un Blob en memoria.
Future<String> getRecordingTempPath() async {
  return '';
}

/// En Web la lectura se efectúa mediante http.get(Uri.parse(blobUrl)).
Future<Uint8List?> readAndClearFileBytes(String path) async {
  return null;
}