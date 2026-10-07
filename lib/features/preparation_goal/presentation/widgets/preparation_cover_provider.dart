import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Caché de fotografías en el deportista; el paquete visual no conoce almacenamiento.
ImageProvider? preparationCoverProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  // En web, el completer de CachedNetworkImage vuelve a decodificar la imagen
  // HTML al reactivar una ruta. Al liberar el fotograma anterior, Flutter limpia
  // ese mismo elemento HTML y la foto queda vacía. El proveedor de Flutter
  // conserva el fotograma estático y usa la caché HTTP del navegador.
  return kIsWeb ? NetworkImage(url) : CachedNetworkImageProvider(url);
}
