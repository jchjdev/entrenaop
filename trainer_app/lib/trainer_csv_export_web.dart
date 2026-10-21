import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> downloadTrainerCsv(String filename, String csv) async {
  final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final blob = web.Blob(
    ['\uFEFF$csv'.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = safeName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // La descarga se resuelve en el navegador, sin enviar resultados a terceros.
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    web.URL.revokeObjectURL(url);
    rethrow;
  }
}
