import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';
import 'package:workout_editor_ui/exercise_video_transport.dart';

// Compatibilidad de ADMIN: la UI común recibe un puerto, no este cliente oficial.
typedef AdminVideoUpload = ExerciseVideoUpload;
typedef AdminVideoStatus = ExerciseVideoStatus;
typedef AdminExerciseVideoRepository = ExerciseVideoSource;

class SupabaseAdminExerciseVideoRepository
    implements AdminExerciseVideoRepository {
  SupabaseAdminExerciseVideoRepository(this._client, {this._transport});
  final SupabaseClient _client;
  final http.Client? _transport;

  @override
  Future<Uint8List> thumbnail(String url) async {
    final owner = _client.auth.currentUser?.id;
    final data = await _call({'action': 'thumbnail', 'url': url});
    final target = Uri.parse(data['url'] as String);
    final reference = Uri.parse(url);
    return ExerciseVideoTransport(transport: _transport)
        .thumbnail(target, reference, checkIdentity: () => _checkOwner(owner));
  }

  void _checkOwner(String? owner) {
    if (_client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

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
    final owner = _client.auth.currentUser?.id;
    await ExerciseVideoTransport(transport: _transport).upload(
      upload,
      bytes,
      contentType,
      onProgress,
      maxBytes: 20 * 1024 * 1024,
      checkIdentity: () => _checkOwner(owner),
    );
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
