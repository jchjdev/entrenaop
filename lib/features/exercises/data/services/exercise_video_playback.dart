import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'exercise_video_controller_web.dart'
    if (dart.library.io) 'exercise_video_controller_io.dart'
    as platform;

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
    final url = Uri.parse(data['url'] as String);
    // La firma no puede convertir una referencia en una descarga a otro destino.
    if (url.scheme != 'https' ||
        url.host != reference.host ||
        url.path != reference.path ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        data['bytes'] is! int ||
        (data['bytes'] as int) <= 0 ||
        (data['bytes'] as int) > 5 * 1024 * 1024) {
      throw const FormatException('Respuesta de vídeo no válida.');
    }
    final controller = await platform.createController(
      url,
      '${client.rest.url}|$owner|${data['cache_key']}',
    );
    if (client.auth.currentUser?.id != owner) {
      await controller.dispose();
      throw StateError('La cuenta ha cambiado.');
    }
    return controller;
  }
}
