import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Clips autorizados: oficiales hasta 5 MiB, privados hasta 50 MiB.
/// Se conservan como máximo veinte archivos y 100 MiB en total.
/// El propietario y el proyecto forman parte de la clave, nunca la firma temporal.
class ExerciseVideoFileCache {
  ExerciseVideoFileCache(this.directory, {this._transport});
  final Directory directory;
  final http.Client? _transport;
  static const maxBytes = 5 * 1024 * 1024;
  static const maxPrivateBytes = 50 * 1024 * 1024;
  static const maxTotalBytes = 100 * 1024 * 1024;
  static const maxFiles = 20;
  static final _pending = <String, Future<File>>{};

  Future<File> get(Uri uri, String key, {int limitBytes = maxBytes}) {
    if (limitBytes <= 0 || limitBytes > maxPrivateBytes) {
      throw const FormatException('El límite de reproducción no es válido.');
    }
    final name = sha256.convert(utf8.encode(key)).toString();
    final pendingKey = '${directory.absolute.path}/$name/$limitBytes';
    return _pending.putIfAbsent(pendingKey, () async {
      try {
        return await _get(uri, name, limitBytes);
      } finally {
        _pending.remove(pendingKey);
      }
    });
  }

  Future<File> _get(Uri uri, String name, int limitBytes) async {
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
          stat.size <= limitBytes &&
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
          (response.contentLength ?? limitBytes + 1) > limitBytes) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException(
          'El vídeo no es un MP4 compatible dentro del tamaño permitido.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > limitBytes) {
          throw const FormatException('El vídeo supera el tamaño permitido.');
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
    final files = <({File file, DateTime modified, int size})>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(r'[/\\][a-f0-9]{64}\.mp4$').hasMatch(entry.path)) {
        continue;
      }
      final stat = await entry.stat();
      if (entry.path != keep &&
          (stat.size > maxPrivateBytes ||
              DateTime.now().difference(stat.modified) >=
                  const Duration(days: 15))) {
        await entry.delete();
      } else {
        files.add((file: entry, modified: stat.modified, size: stat.size));
      }
    }
    files.sort((a, b) => a.modified.compareTo(b.modified));
    var extra = files.length - maxFiles;
    var total = files.fold<int>(0, (sum, entry) => sum + entry.size);
    for (final entry in files) {
      if (extra <= 0 && total <= maxTotalBytes) break;
      if (entry.file.path != keep) {
        await entry.file.delete();
        extra--;
        total -= entry.size;
      }
    }
  }
}
