import 'dart:typed_data';

class ExerciseImageUpload {
  const ExerciseImageUpload({required this.bytes});

  final Uint8List bytes;
  String get contentType => 'image/jpeg';
  String get extension => 'jpg';
}
