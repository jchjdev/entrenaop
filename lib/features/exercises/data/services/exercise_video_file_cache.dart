import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Solo clips oficiales autorizados, hasta 20 archivos de 5 MB (100 MB).
/// El propietario y el proyecto forman parte de la clave, nunca la firma temporal.
class ExerciseVideoFileCache {
  ExerciseVideoFileCache(this.directory, {this._transport});
  final Directory directory;
  final http.Client? _transport;
  static const maxBytes = 5 * 1024 * 1024;
  static const maxFiles = 20;
  static final _pending = <String, Future<File>>{};

  Future<File> get(Uri uri, String key) {
    final name = sha256.convert(utf8.encode(key)).toString();
    final pendingKey = '${directory.absolute.path}/$name';
    return _pending.putIfAbsent(pendingKey, () async {
      try {
        return await _get(uri, name);
      } finally {
        _pending.remove(pendingKey);
      }
    });
  }

  Future<File> _get(Uri uri, String name) async {
    if (uri.scheme != 'https' ||
        !uri.host.endsWith('.b-cdn.net') ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Destino de vídeo no válido.');
    }
    await directory.create(recursive: true);
    final file = File('${directory.path}/$name.mp4');
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size > 0 &&
          stat.size <= maxBytes &&
          DateTime.now().difference(stat.modified) < const Duration(days: 15)) {
        await file.setLastModified(DateTime.now());
        await _trim(keep: file.path);
        return file;
      }
      await file.delete();
    }
    final client = _transport ?? http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.headers['content-type'] ?? '').split(';').first !=
              'video/mp4' ||
          (response.contentLength ?? maxBytes + 1) > maxBytes) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException(
          'El vídeo no es un MP4 compatible de hasta 5 MB.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('El vídeo supera 5 MB.');
        }
        bytes.add(chunk);
      }
      final content = bytes.takeBytes();
      if (content.length < 12 ||
          ascii.decode(content.sublist(4, 8), allowInvalid: true) != 'ftyp' ||
          content.length != response.contentLength) {
        throw const FormatException('El archivo de vídeo está incompleto.');
      }
      // Solo se escribe un archivo completo; los fallos no dejan clips parciales.
      await file.writeAsBytes(content, flush: true);
      await _trim(keep: file.path);
      return file;
    } finally {
      if (_transport == null) client.close();
    }
  }

  Future<void> _trim({required String keep}) async {
    final files = <({File file, DateTime modified})>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(r'[/\\][a-f0-9]{64}\.mp4$').hasMatch(entry.path)) {
        continue;
      }
      final stat = await entry.stat();
      if (entry.path != keep &&
          (stat.size > maxBytes ||
              DateTime.now().difference(stat.modified) >=
                  const Duration(days: 15))) {
        await entry.delete();
      } else {
        files.add((file: entry, modified: stat.modified));
      }
    }
    files.sort((a, b) => a.modified.compareTo(b.modified));
    var extra = files.length - maxFiles;
    for (final entry in files) {
      if (extra <= 0) break;
      if (entry.file.path != keep) {
        await entry.file.delete();
        extra--;
      }
    }
  }
}
