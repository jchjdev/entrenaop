import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'exercise_video_source.dart';

/// Transporte compartido. El adaptador decide identidad, permisos y límites;
/// este cliente solo acepta destinos de subida/reproducción ya autorizados.
class ExerciseVideoTransport {
  const ExerciseVideoTransport({http.Client? transport})
    : _transport = transport;
  final http.Client? _transport;

  Future<void> upload(
    ExerciseVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) onProgress, {
    required int maxBytes,
    void Function()? checkIdentity,
  }) async {
    if (maxBytes <= 0 ||
        maxBytes > 100 * 1024 * 1024 ||
        bytes.isEmpty ||
        bytes.length > maxBytes) {
      throw const FormatException(
        'El archivo supera el tamaño de vídeo permitido.',
      );
    }
    checkIdentity?.call();
    final client = _transport ?? http.Client();
    try {
      final endpoint = Uri.parse('https://video.bunnycdn.com/tusupload');
      final create = http.Request('POST', endpoint)..followRedirects = false;
      create.headers.addAll({
        ...upload.headers,
        'Upload-Length': '${bytes.length}',
        // Bunny exige también título. Se conserva el identificador técnico;
        // no enviamos el nombre local del archivo ni datos del alumno.
        'Upload-Metadata':
            'filetype ${base64Encode(utf8.encode(contentType))},title ${base64Encode(utf8.encode('EntrenaOP ${upload.id}'))}',
      });
      final created = await client
          .send(create)
          .timeout(const Duration(seconds: 30));
      await created.stream.drain<void>();
      checkIdentity?.call();
      final location = created.headers['location'];
      if (created.statusCode != 201 || location == null) {
        throw FormatException(
          'No se pudo iniciar la transferencia (HTTP ${created.statusCode}). La reserva se conserva; reintenta con el archivo original.',
        );
      }
      final target = endpoint.resolve(location);
      if (target.scheme != 'https' ||
          target.host != endpoint.host ||
          target.port != 443 ||
          target.userInfo.isNotEmpty ||
          !target.path.startsWith('/tusupload/')) {
        throw const FormatException(
          'El proveedor devolvió un destino de subida incompatible. La reserva se conserva.',
        );
      }
      var offset = 0;
      var failures = 0;
      while (offset < bytes.length) {
        checkIdentity?.call();
        final end = (offset + 512 * 1024).clamp(0, bytes.length);
        try {
          final request = http.Request('PATCH', target)
            ..followRedirects = false
            ..headers.addAll({
              ...upload.headers,
              'Upload-Offset': '$offset',
              'Content-Type': 'application/offset+octet-stream',
            })
            ..bodyBytes = Uint8List.sublistView(bytes, offset, end);
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 45));
          await response.stream.drain<void>();
          checkIdentity?.call();
          final next = int.tryParse(response.headers['upload-offset'] ?? '');
          if (response.statusCode != 204 || next != end) {
            throw FormatException(
              'Transferencia interrumpida (HTTP ${response.statusCode}). Puedes recuperar la reserva con el archivo original.',
            );
          }
          offset = end;
          failures = 0;
          onProgress(offset / bytes.length);
        } catch (_) {
          checkIdentity?.call();
          if (++failures > 2) rethrow;
          final head = http.Request('HEAD', target)
            ..followRedirects = false
            ..headers.addAll(upload.headers);
          final response = await client
              .send(head)
              .timeout(const Duration(seconds: 15));
          await response.stream.drain<void>();
          checkIdentity?.call();
          final recovered = int.tryParse(
            response.headers['upload-offset'] ?? '',
          );
          if ((response.statusCode != 200 && response.statusCode != 204) ||
              recovered == null ||
              recovered < offset ||
              recovered > end) {
            rethrow;
          }
          offset = recovered;
        }
      }
    } finally {
      if (_transport == null) client.close();
    }
  }

  Future<Uint8List> thumbnail(
    Uri signed,
    Uri reference, {
    void Function()? checkIdentity,
  }) async {
    final parts = reference.pathSegments;
    if (reference.scheme != 'https' ||
        reference.port != 443 ||
        reference.userInfo.isNotEmpty ||
        parts.length != 2 ||
        !reference.host.endsWith('.b-cdn.net') ||
        signed.scheme != 'https' ||
        signed.host != reference.host ||
        signed.port != 443 ||
        signed.userInfo.isNotEmpty ||
        signed.path != '/${parts.first}/thumbnail.jpg') {
      throw const FormatException('La portada recibida no es válida.');
    }
    checkIdentity?.call();
    final client = _transport ?? http.Client();
    try {
      final request = http.Request('GET', signed)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          response.headers['content-type']
                  ?.split(';')
                  .first
                  .trim()
                  .toLowerCase() !=
              'image/jpeg' ||
          (response.contentLength ?? 0) > 2 * 1024 * 1024) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('No se pudo obtener la portada del vídeo.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        checkIdentity?.call();
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('La portada supera el tamaño permitido.');
        }
        bytes.add(chunk);
      }
      if (bytes.isEmpty) throw const FormatException('La portada está vacía.');
      checkIdentity?.call();
      return bytes.takeBytes();
    } finally {
      if (_transport == null) client.close();
    }
  }
}
