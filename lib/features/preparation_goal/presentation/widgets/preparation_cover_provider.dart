import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Caché de fotografías en el deportista; el paquete visual no conoce almacenamiento.
ImageProvider? preparationCoverProvider(String? url) =>
    url == null ? null : CachedNetworkImageProvider(url);
