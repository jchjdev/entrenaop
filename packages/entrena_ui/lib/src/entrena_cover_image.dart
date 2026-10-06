import 'package:flutter/material.dart';

/// Imagen decorativa: el contenido y las acciones nunca esperan a la red.
class EntrenaCoverImage extends StatelessWidget {
  const EntrenaCoverImage({
    super.key,
    this.image,
    this.imageUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
  });
  final ImageProvider? image;
  final String? imageUrl;
  final double focalX, focalY;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(focalX * 2 - 1, focalY * 2 - 1);
    if (image != null) {
      return Image(
        image: image!,
        alignment: alignment,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      );
    }
    if (imageUrl == null) return const SizedBox.expand();
    return Image.network(
      imageUrl!,
      alignment: alignment,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }
}
