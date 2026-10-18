import 'package:video_player/video_player.dart';

// En web el navegador gestiona la caché; no se promete persistencia sin conexión.
Future<VideoPlayerController> createController(
  Uri uri,
  String cacheKey,
) async => VideoPlayerController.networkUrl(uri);
