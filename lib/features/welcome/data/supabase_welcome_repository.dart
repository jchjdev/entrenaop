import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/welcome_repository.dart';

class SupabaseWelcomeRepository implements WelcomeRepository {
  SupabaseWelcomeRepository(
    this.client, {
    required Uri authEndpoint,
    http.Client? httpClient,
  }) : _endpoint = authEndpoint,
       _http = httpClient ?? http.Client();

  static const metadataKey = 'entry_welcome_completed_v1';
  final SupabaseClient client;
  final Uri _endpoint;
  final http.Client _http;
  final _completedThisSession = <String>{};
  final _skippedForNow = <String>{};

  @override
  Future<bool> isCompleted(String userId) async {
    _checkOwner(userId);
    if (_completedThisSession.contains(userId) ||
        _skippedForNow.contains(userId)) {
      return true;
    }
    // Leer Auth evita repetir la bienvenida por metadata de una sesión antigua
    // guardada en otro dispositivo. No se modifica la sesión del SDK.
    final response = await _http
        .get(_endpoint, headers: _headers(userId))
        .timeout(const Duration(seconds: 8));
    _checkOwner(userId);
    final completed =
        _confirmedUser(response, userId).userMetadata?[metadataKey] == true;
    if (completed) _completedThisSession.add(userId);
    return completed;
  }

  void _checkOwner(String userId) {
    if (client.auth.currentUser?.id != userId ||
        client.auth.currentSession == null ||
        client.auth.currentUser!.isAnonymous) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Map<String, String> _headers(String userId) {
    _checkOwner(userId);
    return {
      for (final entry in client.auth.headers.entries)
        if (entry.key.toLowerCase() != 'authorization') entry.key: entry.value,
      'Authorization': 'Bearer ${client.auth.currentSession!.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  User _confirmedUser(http.Response response, String userId) {
    if (response.statusCode != 200) {
      throw StateError('No se pudo guardar la preferencia.');
    }
    final user = User.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (user?.id != userId) throw StateError('La cuenta ha cambiado.');
    return user!;
  }

  @override
  Future<void> complete(String userId) async {
    _checkOwner(userId);
    if (!_completedThisSession.contains(userId)) {
      // Token fijado antes de enviar: una respuesta tardía nunca reemplaza
      // la sesión de otra cuenta. Auth fusiona exclusivamente esta clave.
      final response = await _http
          .put(
            _endpoint,
            headers: _headers(userId),
            body: jsonEncode({
              'data': {metadataKey: true},
            }),
          )
          .timeout(const Duration(seconds: 15));
      _checkOwner(userId);
      if (_confirmedUser(response, userId).userMetadata?[metadataKey] != true) {
        throw StateError('No se pudo confirmar la preferencia.');
      }
    }
    _completedThisSession.add(userId);
    _skippedForNow.remove(userId);
  }

  @override
  void skipForSession(String userId) {
    _checkOwner(userId);
    _skippedForNow.add(userId);
  }

  void dispose() => _http.close();
}
