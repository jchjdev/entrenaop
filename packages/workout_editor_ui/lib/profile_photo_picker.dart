import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import 'program_cover_image_draft.dart';

/// Selección local y encuadre circular; cancelar no sube ningún archivo.
Future<Uint8List?> pickProfilePhoto(BuildContext context) async {
  final selected = await pickProgramCoverImage();
  if (selected == null || !context.mounted) return null;
  final decoded = await decodeImageFromList(selected.header);
  final width = decoded.width, height = decoded.height;
  decoded.dispose();
  if (!context.mounted) return null;
  final crop = await showDialog<({double x, double y, double size})>(
    context: context,
    builder: (context) {
      final viewport = MediaQuery.sizeOf(context);
      final side = math.max(
        100.0,
        math.min(340.0, math.min(viewport.width - 80, viewport.height * .5)),
      );
      return ProfilePhotoCropDialog(
        bytes: selected.header,
        width: width,
        height: height,
        side: side,
      );
    },
  );
  if (crop == null) return null;
  return compute(_encodeCrop, (
    bytes: selected.header,
    x: crop.x,
    y: crop.y,
    size: crop.size,
  ));
}

Uint8List encodeProfilePhotoCrop(
  Uint8List bytes, {
  required double x,
  required double y,
  required double size,
}) => _encodeCrop((bytes: bytes, x: x, y: y, size: size));

Uint8List _encodeCrop(
  ({Uint8List bytes, double x, double y, double size}) input,
) {
  try {
    return _validatedCrop(input);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Elige una fotografía válida.');
  }
}

Uint8List _validatedCrop(
  ({Uint8List bytes, double x, double y, double size}) input,
) {
  if (![input.x, input.y, input.size].every((n) => n.isFinite) ||
      input.x < 0 ||
      input.y < 0 ||
      input.size <= 0 ||
      input.bytes.length < 16 ||
      input.bytes.length > 500 * 1024) {
    throw const FormatException('No se pudo aplicar el encuadre de la foto.');
  }
  final decoder = image.findDecoderForData(input.bytes);
  final info = decoder?.startDecode(input.bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 24000000) {
    throw const FormatException('Elige una fotografía válida.');
  }
  final original = decoder!.decodeFrame(0);
  if (original == null) {
    throw const FormatException('Elige una fotografía válida.');
  }
  final x = input.x.round().clamp(0, original.width - 1),
      y = input.y.round().clamp(0, original.height - 1);
  final edge = math.min(
    input.size.round(),
    math.min(original.width - x, original.height - y),
  );
  if (edge < 1) {
    throw const FormatException('No se pudo aplicar el encuadre de la foto.');
  }
  final cropped = image.copyResize(
    image.copyCrop(original, x: x, y: y, width: edge, height: edge),
    width: 512,
    height: 512,
  );
  // El pipeline de selección ya reencodifica sin EXIF/GPS. Se crea además una
  // imagen RGB nueva para que el archivo final solo contenga los píxeles elegidos.
  final clean = image.Image(width: 512, height: 512, numChannels: 3);
  image.compositeImage(clean, cropped);
  for (final quality in [84, 74, 64, 54]) {
    final result = Uint8List.fromList(image.encodeJpg(clean, quality: quality));
    if (result.length <= 200 * 1024) return result;
  }
  throw const FormatException('Elige una fotografía más sencilla.');
}

class ProfilePhotoCropDialog extends StatefulWidget {
  const ProfilePhotoCropDialog({
    super.key,
    required this.bytes,
    required this.width,
    required this.height,
    required this.side,
  });
  final Uint8List bytes;
  final int width, height;
  final double side;
  @override
  State<ProfilePhotoCropDialog> createState() => _PhotoCropState();
}

class _PhotoCropState extends State<ProfilePhotoCropDialog> {
  late final double _base = widget.side / math.min(widget.width, widget.height);
  late final _controller = TransformationController(
    Matrix4.translationValues(
      (widget.side - widget.width * _base) / 2,
      (widget.side - widget.height * _base) / 2,
      0,
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.side + 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajustar foto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Arrastra la imagen y amplía para elegir el encuadre.'),
            const SizedBox(height: 16),
            ClipOval(
              child: SizedBox(
                width: widget.side,
                height: widget.side,
                child: InteractiveViewer(
                  constrained: false,
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: widget.width * _base,
                    height: widget.height * _base,
                    child: Image.memory(widget.bytes, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final scale = _controller.value.getMaxScaleOnAxis();
                    final translation = _controller.value.getTranslation();
                    Navigator.pop(context, (
                      x: math.max(0.0, -translation.x / (_base * scale)),
                      y: math.max(0.0, -translation.y / (_base * scale)),
                      size: widget.side / (_base * scale),
                    ));
                  },
                  child: const Text('Usar foto'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
