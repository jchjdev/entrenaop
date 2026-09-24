import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:workout_editor_ui/exercise_image_draft.dart';

void main() {
  test('reduce y normaliza una fotografía antes de subirla', () async {
    final source = image.Image(width: 1800, height: 1200);
    image.fill(source, color: image.ColorRgb8(80, 130, 190));

    final result = await optimizeExerciseImage(
      Uint8List.fromList(image.encodePng(source)),
    );
    final decoded = image.decodeJpg(result.bytes);

    expect(result.contentType, 'image/jpeg');
    expect(result.bytes.length, lessThanOrEqualTo(exerciseImageMaxBytes));
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1280));
    expect(decoded.height, lessThanOrEqualTo(720));
  });
}
