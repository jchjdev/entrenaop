import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVideoUpload {
  const AdminVideoUpload({required this.id, required this.headers});
  final String id;
  final Map<String, String> headers;
}

class AdminVideoStatus {
  const AdminVideoStatus(this.status, [this.url]);
  final String status;
  final String? url;
}

abstract class AdminExerciseVideoRepository {
  Future<AdminVideoUpload> create(int bytes);
  Future<void> upload(
    AdminVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) onProgress,
  );
  Future<AdminVideoStatus> status(String id);
  Future<Uri> playback(String url);
}

class SupabaseAdminExerciseVideoRepository
    implements AdminExerciseVideoRepository {
  SupabaseAdminExerciseVideoRepository(this._client, {this._transport});
  final SupabaseClient _client;
  final http.Client? _transport;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw StateError('Inicia sesión de nuevo.');
    final response = await _client.functions.invoke(
      'exercise-video',
      body: {...body, 'expected_user_id': owner},
    );
    if (_client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<AdminVideoUpload> create(int bytes) async {
    if (bytes <= 0 || bytes > 20 * 1024 * 1024) {
      throw const FormatException('El archivo debe ocupar como máximo 20 MB.');
    }
    final data = await _call({'action': 'create', 'bytes': bytes});
    return AdminVideoUpload(
      id: data['id'] as String,
      headers: {
        'AuthorizationSignature': data['signature'] as String,
        'AuthorizationExpire': '${data['expiration']}',
        'LibraryId': '${data['library_id']}',
        'VideoId': data['video_id'] as String,
        'Tus-Resumable': '1.0.0',
      },
    );
  }

  @override
  Future<void> upload(
    AdminVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) onProgress,
  ) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('El archivo debe ocupar como máximo 20 MB.');
    }
    final client = _transport ?? http.Client();
    try {
      final endpoint = Uri.parse('https://video.bunnycdn.com/tusupload');
      final create = http.Request('POST', endpoint)..followRedirects = false;
      create.headers.addAll({
        ...upload.headers,
        'Upload-Length': '${bytes.length}',
        'Upload-Metadata': 'filetype ${base64Encode(utf8.encode(contentType))}',
      });
      final created = await client
          .send(create)
          .timeout(const Duration(seconds: 30));
      await created.stream.drain<void>();
      final location = created.headers['location'];
      if (created.statusCode != 201 || location == null) {
        throw StateError('No se pudo iniciar la subida.');
      }
      final target = endpoint.resolve(location);
      // Nunca enviar la autorización de subida a otro host ni seguir redirecciones.
      if (target.scheme != 'https' ||
          target.host != endpoint.host ||
          target.port != 443 ||
          target.userInfo.isNotEmpty ||
          !target.path.startsWith('/tusupload/')) {
        throw StateError('El destino de subida no es válido.');
      }
      var offset = 0;
      var failures = 0;
      while (offset < bytes.length) {
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
          final next = int.tryParse(response.headers['upload-offset'] ?? '');
          if (response.statusCode != 204 || next != end) {
            throw StateError('Subida interrumpida.');
          }
          offset = end;
          failures = 0;
          onProgress(offset / bytes.length);
        } catch (_) {
          if (++failures > 2) rethrow;
          // Recupera el offset confirmado: no repite a ciegas un fragmento ya recibido.
          final head = http.Request('HEAD', target)
            ..followRedirects = false
            ..headers.addAll(upload.headers);
          final response = await client
              .send(head)
              .timeout(const Duration(seconds: 15));
          await response.stream.drain<void>();
          final recovered = int.tryParse(
            response.headers['upload-offset'] ?? '',
          );
          if (response.statusCode != 200 && response.statusCode != 204 ||
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

  @override
  Future<AdminVideoStatus> status(String id) async {
    final data = await _call({'action': 'status', 'id': id});
    return AdminVideoStatus(data['status'] as String, data['url'] as String?);
  }

  @override
  Future<Uri> playback(String url) async {
    final data = await _call({'action': 'playback', 'url': url});
    return Uri.parse(data['url'] as String);
  }
}
