import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:workout_core/exercise_image.dart';

const exerciseImageMaxBytes = 500 * 1024;

@immutable
class ExerciseFormSubmission<T> {
  const ExerciseFormSubmission({
    required this.draft,
    this.image,
    this.removeExistingImage = false,
  });

  final T draft;
  final ExerciseImageUpload? image;
  final bool removeExistingImage;
}

Future<ExerciseImageUpload> optimizeExerciseImage(Uint8List source) async {
  final bytes = await compute(_encodeExerciseImage, source);
  if (bytes.length > exerciseImageMaxBytes) {
    throw const FormatException(
      'La foto no se puede reducir por debajo de 500 KB. Elige otra imagen.',
    );
  }
  return ExerciseImageUpload(bytes: bytes);
}

Uint8List _encodeExerciseImage(Uint8List source) {
  var decoded = image.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('El archivo elegido no es una imagen válida.');
  }
  decoded = image.bakeOrientation(decoded);

  image.Image resized = decoded;
  if (decoded.width > 1280 || decoded.height > 720) {
    resized = image.copyResize(
      decoded,
      width: 1280,
      height: 720,
      maintainAspect: true,
      interpolation: image.Interpolation.average,
    );
  }

  for (final quality in const [82, 76, 70, 64]) {
    final encoded = Uint8List.fromList(
      image.encodeJpg(resized, quality: quality),
    );
    if (encoded.length <= exerciseImageMaxBytes) return encoded;
  }

  final compact = image.copyResize(
    resized,
    width: 1024,
    height: 576,
    maintainAspect: true,
    interpolation: image.Interpolation.average,
  );
  return Uint8List.fromList(image.encodeJpg(compact, quality: 64));
}
