import 'dart:async';

import 'package:entrenaop/features/exercises/presentation/widgets/exercise_reference_video.dart';
import 'package:entrenaop/features/exercises/presentation/widgets/exercise_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  testWidgets('abre referencias externas y conserva el enlace si falla', (
    tester,
  ) async {
    Uri? opened;
    var success = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseReferenceVideo(
            url: 'https://www.youtube.com/watch?v=fixture',
            openExternal: (uri) async {
              opened = uri;
              return success;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir enlace original'));
    await tester.pumpAndSettle();
    expect(opened!.host, 'www.youtube.com');
    expect(
      find.text('No se ha podido abrir el enlace. Puedes copiarlo.'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsOneWidget);
    success = true;
    await tester.tap(find.text('Abrir enlace original'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se ha podido abrir el enlace. Puedes copiarlo.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'carga bajo demanda, reintenta y libera el reproductor al cerrar',
    (tester) async {
      final failed = _Controller()..fail = true;
      final ready = _Controller();
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseReferenceVideo(
                url: 'https://example.invalid/demo.mp4',
                createController: (_) => ++loads == 1 ? failed : ready,
              ),
            ),
          ),
        ),
      );
      expect(loads, 0);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(failed.disposals, 1);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(ready.value.isPlaying, true);
      await tester.tap(find.byTooltip('Pausar vídeo'));
      await tester.pump();
      expect(ready.value.isPlaying, false);
      expect(ready.volumeChanges, 0);
      await tester.pumpWidget(const SizedBox());
      expect(ready.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la ficha usa la foto como portada del único bloque de vídeo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExerciseDetailSheet(
            name: 'Flexiones',
            description: 'Descripción debajo del vídeo.',
            imageUrl: 'https://example.invalid/poster.jpg',
            videoUrl: 'https://fixture.b-cdn.net/video/play_360p.mp4',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ExerciseReferenceVideo), findsOneWidget);
    expect(find.text('Vídeo de referencia'), findsNothing);
    expect(find.text('Ver vídeo'), findsNothing);
    final poster = tester.getRect(find.byType(AspectRatio).first);
    final play = tester.getCenter(find.byIcon(Icons.play_arrow_rounded));
    expect(play.dx, greaterThan(poster.center.dx));
    expect(play.dy, greaterThan(poster.center.dy));
    expect(
      tester.getTopLeft(find.byType(ExerciseReferenceVideo)).dy,
      lessThan(
        tester.getTopLeft(find.text('Descripción debajo del vídeo.')).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la portada permanece al cargar y se sustituye por el vídeo', (
    tester,
  ) async {
    final gate = Completer<void>();
    final controller = _Controller()..gate = gate;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseReferenceVideo(
            url: 'https://fixture.b-cdn.net/video/play_360p.mp4',
            posterUrl: 'https://example.invalid/poster.jpg',
            createController: (_) => controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(controller.value.isInitialized, false);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(controller.value.isPlaying, true);
    expect(controller.volumeChanges, 0);
    await tester.pumpWidget(const SizedBox());
    expect(controller.disposals, 1);
  });

  testWidgets(
    'si el navegador bloquea el arranque permite otro toque sin recargar',
    (tester) async {
      final controller = _Controller()..playFailures = 1;
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseReferenceVideo(
                url: 'https://fixture.b-cdn.net/video/play_360p.mp4',
                createController: (_) {
                  loads++;
                  return controller;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(controller.value.isInitialized, true);
      expect(controller.value.isPlaying, false);
      expect(controller.disposals, 0);
      await tester.tap(find.byTooltip('Reproducir vídeo'));
      await tester.pump();
      expect(controller.value.isPlaying, true);
      expect(loads, 1);
      controller.value = controller.value.copyWith(
        isPlaying: false,
        position: controller.value.duration,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Reproducir vídeo'));
      await tester.pump();
      expect(controller.value.position, Duration.zero);
      expect(controller.value.isPlaying, true);
      await tester.pumpWidget(const SizedBox());
      expect(controller.disposals, 1);
    },
  );

  testWidgets('cerrar durante la inicialización libera la carga tardía', (
    tester,
  ) async {
    final gate = Completer<void>();
    final controller = _Controller()..gate = gate;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseReferenceVideo(
            url: 'https://example.invalid/demo.mp4',
            createController: (_) => controller,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();
    expect(controller.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rechaza enlaces no HTTPS sin abrir el reproductor', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseReferenceVideo(
            url: 'http://example.invalid/demo.mp4',
            createController: (_) {
              loads++;
              return _Controller();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(loads, 0);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Controller extends VideoPlayerController {
  _Controller()
    : super.networkUrl(Uri.parse('https://example.invalid/demo.mp4'));
  bool fail = false;
  int disposals = 0;
  int volumeChanges = 0;
  int playFailures = 0;
  Completer<void>? gate;
  @override
  Future<void> initialize() async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('Fallo simulado');
    value = VideoPlayerValue(
      duration: const Duration(seconds: 12),
      size: const Size(640, 360),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    if (playFailures > 0) {
      playFailures--;
      throw StateError('El navegador necesita otra interacción.');
    }
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeChanges++;
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}
