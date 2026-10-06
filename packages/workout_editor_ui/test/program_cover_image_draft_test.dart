import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:workout_editor_ui/program_cover_image_draft.dart';

void main() {
  test('crea dos JPEG ligeros manteniendo el encuadre y sin ampliar', () async {
    final source = image.Image(width: 1920, height: 1080);
    image.fill(source, color: image.ColorRgb8(80, 130, 190));
    final result = await optimizeProgramCoverImage(
      Uint8List.fromList(image.encodePng(source)),
    );
    final card = image.decodeJpg(result.card)!;
    final header = image.decodeJpg(result.header)!;
    expect([card.width, card.height], [800, 450]);
    expect([header.width, header.height], [1600, 900]);
    expect(result.card.length, lessThanOrEqualTo(180 * 1024));
    expect(result.header.length, lessThanOrEqualTo(500 * 1024));
    final small = await optimizeProgramCoverImage(
      Uint8List.fromList(image.encodePng(image.Image(width: 80, height: 160))),
    );
    expect(image.decodeJpg(small.header)!.width, 80);
    expect(image.decodeJpg(small.header)!.height, 160);
  });

  test('aplana transparencias sobre el fondo de marca', () async {
    final source = image.Image(width: 10, height: 10, numChannels: 4);
    final result = await optimizeProgramCoverImage(
      Uint8List.fromList(image.encodePng(source)),
    );
    final decoded = image.decodeJpg(result.card)!;
    expect(decoded.numChannels, 3);
    expect(decoded.getPixel(0, 0).r, closeTo(9, 2));
    expect(decoded.getPixel(0, 0).g, closeTo(10, 2));
    expect(decoded.getPixel(0, 0).b, closeTo(13, 2));
    expect(decoded.exif.isEmpty, isTrue);
  });

  test('rechaza archivos inválidos o desproporcionados', () async {
    await expectLater(
      optimizeProgramCoverImage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    await expectLater(
      optimizeProgramCoverImage(Uint8List(12 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    final giant = image.Image(width: 5001, height: 4800);
    await expectLater(
      optimizeProgramCoverImage(Uint8List.fromList(image.encodePng(giant))),
      throwsFormatException,
    );
  });
}
