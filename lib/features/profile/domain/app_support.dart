/// Destinos públicos: una opción sin destino operativo no se muestra en Ajustes.
class AppSupportResources {
  const AppSupportResources({
    this.email = 'ayuda@entrenaop.es',
    this.instagram,
    this.rating,
    this.promotion,
  });
  final String email;
  final Uri? instagram, rating, promotion;

  Uri reportUri(String description, {String? diagnostic}) => Uri(
    scheme: 'mailto',
    path: email,
    // mailto requiere %20: queryParameters codifica espacios como +.
    query:
        'subject=${Uri.encodeComponent('Ayuda con EntrenaOP')}&body=${Uri.encodeComponent([description.trim(), if (diagnostic != null) '\nDatos de la instalación:\n$diagnostic'].join('\n'))}',
  );
}

typedef OpenSupportLink = Future<bool> Function(Uri uri);
