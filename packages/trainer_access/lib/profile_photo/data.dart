import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../authenticated_rpc.dart';
import 'domain.dart';

class SupabaseProfilePhotoRepository implements ProfilePhotoRepository {
  SupabaseProfilePhotoRepository(this.client, {required this.ownerId});
  final SupabaseClient client;
  @override
  final String ownerId;
  void _identity() {
    if (client.auth.currentUser?.id != ownerId) {
      throw StateError('La cuenta ha cambiado. Vuelve a abrir Perfil.');
    }
  }

  Future<void> _ready() async {
    _identity();
    if (client.auth.currentSession?.isExpired ?? true) {
      await client.auth.getSession();
      _identity();
    }
    if (client.auth.currentSession?.isExpired ?? true) {
      throw StateError('La sesión necesita renovarse antes de continuar.');
    }
  }

  Future<ProfilePhotoState> _rpc(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final result = await authenticatedTrainerRpc(
        client,
        ownerId,
        name,
        params: {'p_expected_owner': ownerId, ...?params},
      );
      final row = Map<String, dynamic>.from(result as Map);
      return ProfilePhotoState(
        path: row['path'] as String?,
        revision: (row['revision'] as num).toInt(),
      );
    } on PostgrestException catch (error) {
      throw ProfilePhotoFailure(
        error.code == '40001'
            ? 'La foto cambió en otra sesión. Usa «Descartar cambio pendiente» para cargar la foto actual.'
            : 'No se pudo guardar la foto. Comprueba tu sesión y reintenta.',
      );
    }
  }

  @override
  Future<ProfilePhotoState> own() => _rpc('get_my_profile_photo');
  @override
  Future<ProfilePhotoState> save(String? path, {required int revision}) =>
      _rpc('set_my_profile_photo', {'p_path': path, 'p_revision': revision});
  @override
  Future<Uint8List> download(String path) async {
    await _ready();
    final result = await client.storage.from('profile-photos').download(path);
    _identity();
    return result;
  }

  @override
  Future<String> upload(Uint8List bytes, String id) async {
    await _ready();
    if (bytes.isEmpty || bytes.length > 500 * 1024) {
      throw const FormatException('Elige una foto de hasta 500 KB.');
    }
    final path = '$ownerId/$id.jpg';
    try {
      await client.storage
          .from('profile-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
            ),
          );
    } catch (_) {
      // Un reintento conserva el identificador. Solo se acepta un archivo ya
      // subido si coincide exactamente; jamás se sobrescribe la foto vigente.
      var same = false;
      try {
        final existing = await download(path);
        same = existing.length == bytes.length;
        for (var i = 0; same && i < bytes.length; i++) {
          same = existing[i] == bytes[i];
        }
      } catch (_) {
        /* Se conserva el error original de subida. */
      }
      if (!same) rethrow;
    }
    _identity();
    return path;
  }

  @override
  Future<void> discard(String path) async {
    await _ready();
    await client.storage.from('profile-photos').remove([path]);
    _identity();
  }

  @override
  Future<void> cleanup() async {
    await _ready();
    final files = await client.storage
        .from('profile-photos')
        .list(path: ownerId);
    _identity();
    final current = await own();
    for (final file in files) {
      final path = '$ownerId/${file.name}';
      if (path != current.path && file.name.endsWith('.jpg')) {
        await discard(path);
      }
    }
  }
}
