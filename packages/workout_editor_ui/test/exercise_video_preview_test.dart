import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
// La interfaz ya resuelta por video_player permite simular el plugin en este test.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

class PreviewSource extends Fake implements ExerciseVideoSource {
  int calls = 0;
  Completer<Uri>? pending;
  @override
  Future<Uri> playback(String url) {
    calls++;
    return pending?.future ?? Future.error(StateError('Sin acceso al recurso'));
  }
}

class _ReadySource extends PreviewSource {
  @override
  Future<Uri> playback(String url) async {
    calls++;
    return Uri.parse(url);
  }
}

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform(this.size);
  final Size size;
  int plays = 0;
  Duration position = Duration.zero;
  final events = StreamController<VideoEvent>();
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 90),
        size: size,
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> dispose(int playerId) async {
    await events.close();
  }
}

Widget app(
  PreviewSource source, [
  String url = 'https://fixture.b-cdn.net/one/play_720p.mp4',
]) => MaterialApp(
  home: Scaffold(
    body: ExerciseVideoPreview(url: url, source: source),
  ),
);

void main() {
  for (final width in [390.0, 1600.0]) {
    for (final size in [const Size(720, 1280), const Size(1280, 720)]) {
      testWidgets(
        'consulta compacta conserva proporción y controles a $width px: $size',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final original = VideoPlayerPlatform.instance;
          final platform = FakeVideoPlayerPlatform(size);
          VideoPlayerPlatform.instance = platform;
          addTearDown(() => VideoPlayerPlatform.instance = original);
          final source = _ReadySource();
          double? selected;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ExerciseVideoPreview(
                    url: 'https://fixture.b-cdn.net/video.mp4',
                    source: source,
                    onPositionSelected: (value) => selected = value,
                  ),
                ),
              ),
            ),
          );
          expect(source.calls, 0);
          await tester.tap(find.text('Reproducir vídeo'));
          await tester.pumpAndSettle();
          final rendered = tester.getSize(find.byType(VideoPlayer));
          expect(rendered.height, lessThanOrEqualTo(360));
          expect(rendered.width, lessThanOrEqualTo(width));
          expect(rendered.aspectRatio, closeTo(size.aspectRatio, 0.001));
          expect(tester.getBottomRight(find.byType(Slider)).dy, lessThan(640));
          expect(
            find.text('Comentar este instante').hitTestable(),
            findsOneWidget,
          );
          expect(platform.plays, 0);
          tester.widget<Slider>(find.byType(Slider)).onChanged!(12500);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Comentar este instante'));
          await tester.pumpAndSettle();
          expect(selected, 12.5);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'no reproduce al consultar y permite reintentar autorización fallida',
    (tester) async {
      final source = PreviewSource();
      await tester.pumpWidget(app(source));
      expect(source.calls, 0);
      await tester.tap(find.text('Reproducir vídeo'));
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      expect(find.textContaining('Puedes reintentar'), findsOneWidget);
      await tester.tap(find.text('Reproducir vídeo'));
      await tester.pumpAndSettle();
      expect(source.calls, 2);
    },
  );
  testWidgets(
    'cambiar recurso descarta autorización tardía antes de cargar el archivo',
    (tester) async {
      final source = PreviewSource()..pending = Completer<Uri>();
      await tester.pumpWidget(app(source));
      await tester.tap(find.text('Reproducir vídeo'));
      await tester.pump();
      await tester.pumpWidget(
        app(source, 'https://fixture.b-cdn.net/two/play_720p.mp4'),
      );
      source.pending!.complete(
        Uri.parse('https://fixture.b-cdn.net/one/play_720p.mp4?token=old'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reproducir vídeo'), findsOneWidget);
      expect(find.textContaining('No se pudo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cerrar descarta autorización tardía sin inicializar reproductor',
    (tester) async {
      final source = PreviewSource()..pending = Completer<Uri>();
      await tester.pumpWidget(app(source));
      await tester.tap(find.text('Reproducir vídeo'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      source.pending!.complete(
        Uri.parse('https://fixture.b-cdn.net/one/play_720p.mp4?token=old'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
