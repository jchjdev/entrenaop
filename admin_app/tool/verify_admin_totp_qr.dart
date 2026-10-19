import 'dart:io';

import 'package:entrenaop_admin/features/auth/presentation/admin_totp_qr_source.dart';

void main() {
  // Prueba visual sin autenticación, factores ni secretos; no forma parte del ZIP.
  const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="210" height="210">'
      '<rect width="210" height="210" fill="#ffffff"/>'
      '<path fill="#000000" d="M10 10h70v70H10zM130 10h70v70h-70zM10 130h70v70H10zM110 110h30v30h-30zM160 160h40v40h-40z"/>'
      '</svg>';
  final source = adminTotpQrImageSource('data:image/svg+xml;utf-8,$svg');
  final output = File('build/qr-image-check.html');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('''<!doctype html>
<html lang="es"><meta charset="utf-8"><title>Comprobación de imagen del autenticador</title>
<body style="background:#101318;color:#fff;font:18px sans-serif;padding:40px">
<h1>Comprobación de imagen del autenticador</h1>
<p>Imagen sintética: sin cuenta, clave ni código de autenticación.</p>
<img alt="Imagen de prueba del formato de GoTrue" width="210" height="210" src="$source">
<p>La imagen debe verse con cuadrados negros sobre fondo blanco.</p>
</body></html>''');
  stdout.writeln(output.absolute.path);
}
