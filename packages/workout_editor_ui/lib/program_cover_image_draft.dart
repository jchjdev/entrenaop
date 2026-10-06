import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

class ProgramCoverImageDraft {
  const ProgramCoverImageDraft({required this.card, required this.header});
  final Uint8List card, header;
}

Future<ProgramCoverImageDraft?> pickProgramCoverImage() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  // Evita decodificar originales desproporcionados en el navegador del admin.
  if (await picked.length() > 12 * 1024 * 1024) {
    throw const FormatException('Elige una imagen de hasta 12 MB.');
  }
  return optimizeProgramCoverImage(await picked.readAsBytes());
}

Future<ProgramCoverImageDraft> optimizeProgramCoverImage(Uint8List source) =>
    compute(_encode, source);

ProgramCoverImageDraft _encode(Uint8List source) {
  try {
    return _encodeValidated(source);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'No se pudo leer la imagen. Elige una fotografía válida.',
    );
  }
}

ProgramCoverImageDraft _encodeValidated(Uint8List source) {
  if (source.length > 12 * 1024 * 1024) {
    throw const FormatException('Elige una imagen de hasta 12 MB.');
  }
  final decoder = image.findDecoderForData(source);
  final info = decoder?.startDecode(source);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 24000000) {
    throw const FormatException(
      'Elige una imagen válida de hasta 24 megapíxeles.',
    );
  }
  final raw = decoder!.decodeFrame(0);
  if (raw == null) throw const FormatException('No se pudo leer la imagen.');
  final oriented = image.bakeOrientation(raw);
  // JPEG opaco y sin EXIF/GPS; se conserva la proporción y el encuadre se aplica al mostrar.
  final opaque = image.Image(
    width: oriented.width,
    height: oriented.height,
    numChannels: 3,
  );
  image.fill(opaque, color: image.ColorRgb8(9, 10, 13));
  image.compositeImage(opaque, oriented);
  Uint8List encode(int maxEdge, int maxBytes) {
    final ratio = math.min(
      1.0,
      maxEdge / math.max(opaque.width, opaque.height),
    );
    final resized = image.copyResize(
      opaque,
      width: math.max(1, (opaque.width * ratio).round()),
      height: math.max(1, (opaque.height * ratio).round()),
      interpolation: image.Interpolation.average,
    );
    for (final quality in [84, 78, 72, 66, 60, 52]) {
      final result = Uint8List.fromList(
        image.encodeJpg(resized, quality: quality),
      );
      if (result.length <= maxBytes) return result;
    }
    throw const FormatException(
      'No se pudo optimizar la foto. Elige una imagen más sencilla.',
    );
  }

  return ProgramCoverImageDraft(
    card: encode(800, 180 * 1024),
    header: encode(1600, 500 * 1024),
  );
}
