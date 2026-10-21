import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'exercise_video_controller_web.dart'
    if (dart.library.io) 'exercise_video_controller_io.dart'
    as platform;

/// Solo la respuesta autenticada fija la cota; un scope desconocido se rechaza.
class ExerciseVideoAuthorization {
  const ExerciseVideoAuthorization._(this.url, this.cacheKey, this.limitBytes);
  final Uri url;
  final String cacheKey;
  final int limitBytes;

  factory ExerciseVideoAuthorization.fromResponse(
    Uri reference,
    Map<String, dynamic> data,
  ) {
    final scope = data['scope'] ?? 'official';
    final ceiling = switch (scope) {
      'official' => 5 * 1024 * 1024,
      'trainer_exercise' || 'client_technique' => 50 * 1024 * 1024,
      _ => throw const FormatException('Alcance de vídeo no válido.'),
    };
    final limit =
        data['playback_limit'] ?? (scope == 'official' ? ceiling : null);
    final rawUrl = data['url'];
    final bytes = data['bytes'];
    final key = data['cache_key'];
    if (rawUrl is! String ||
        limit is! int ||
        limit <= 0 ||
        limit > ceiling ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > limit ||
        key is! String ||
        key.isEmpty ||
        key.length > 128) {
      throw const FormatException('Respuesta de vídeo no válida.');
    }
    final url = Uri.parse(rawUrl);
    if (reference.scheme != 'https' ||
        reference.userInfo.isNotEmpty ||
        reference.port != 443 ||
        url.scheme != 'https' ||
        url.host != reference.host ||
        url.path != reference.path ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        url.fragment.isNotEmpty) {
      throw const FormatException('Destino de vídeo no válido.');
    }
    return ExerciseVideoAuthorization._(url, key, limit);
  }
}

class ExerciseVideoPlayback {
  const ExerciseVideoPlayback(this.client);
  final SupabaseClient client;

  Future<VideoPlayerController> createController(Uri reference) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw StateError('Inicia sesión para consultar el vídeo.');
    }
    late final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'exercise-video',
        body: {
          'action': 'playback',
          'url': reference.toString(),
          'expected_user_id': owner,
        },
      );
    } on FunctionException catch (error) {
      if (client.auth.currentUser?.id == owner &&
          error.status == 404 &&
          error.details is Map &&
          error.details['error'] == 'video_not_managed') {
        // Los enlaces externos anteriores no se convierten en recursos gestionados.
        return VideoPlayerController.networkUrl(reference);
      }
      rethrow;
    }
    if (client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final authorized = ExerciseVideoAuthorization.fromResponse(reference, data);
    final controller = await platform.createController(
      authorized.url,
      '${client.rest.url}|$owner|${authorized.cacheKey}',
      maxBytes: authorized.limitBytes,
    );
    if (client.auth.currentUser?.id != owner) {
      await controller.dispose();
      throw StateError('La cuenta ha cambiado.');
    }
    return controller;
  }
}
