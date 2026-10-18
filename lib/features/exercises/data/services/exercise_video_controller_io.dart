import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'exercise_video_file_cache.dart';

Future<VideoPlayerController> createController(Uri uri, String cacheKey) async {
  final root = await getTemporaryDirectory();
  final cache = ExerciseVideoFileCache(
    Directory('${root.path}/entrenaop-exercise-videos-v1'),
  );
  final file = await cache.get(uri, cacheKey);
  return VideoPlayerController.file(file);
}
