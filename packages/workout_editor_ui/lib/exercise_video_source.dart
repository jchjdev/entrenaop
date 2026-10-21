import 'dart:typed_data';

/// Puerto técnico de medios: el consumidor mantiene permisos, destino y transporte.
class ExerciseVideoUpload {
  const ExerciseVideoUpload({required this.id, required this.headers});
  final String id;
  final Map<String, String> headers;
}

class ExerciseVideoStatus {
  const ExerciseVideoStatus(this.status, [this.url]);
  final String status;
  final String? url;
}

abstract class ExerciseVideoSource {
  Future<ExerciseVideoUpload> create(int bytes);
  Future<void> upload(
    ExerciseVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) onProgress,
  );
  Future<ExerciseVideoStatus> status(String id);
  Future<Uri> playback(String url);
  Future<Uint8List> thumbnail(String url);
}
