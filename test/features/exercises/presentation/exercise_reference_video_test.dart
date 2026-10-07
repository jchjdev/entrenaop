import 'dart:async';

import 'package:entrenaop/features/exercises/presentation/widgets/exercise_reference_video.dart';
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
      await tester.tap(find.text('Ver vídeo'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar vídeo'), findsOneWidget);
      expect(failed.disposals, 1);
      await tester.tap(find.text('Reintentar vídeo'));
      await tester.pumpAndSettle();
      expect(ready.value.isPlaying, false);
      await tester.tap(find.byTooltip('Reproducir vídeo'));
      await tester.pump();
      expect(ready.value.isPlaying, true);
      await tester.tap(find.byTooltip('Pausar vídeo'));
      await tester.pump();
      expect(ready.value.isPlaying, false);
      await tester.pumpWidget(const SizedBox());
      expect(ready.disposals, 1);
      expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('Ver vídeo'));
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
    await tester.tap(find.text('Ver vídeo'));
    await tester.pumpAndSettle();
    expect(loads, 0);
    expect(find.text('Reintentar vídeo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Controller extends VideoPlayerController {
  _Controller()
    : super.networkUrl(Uri.parse('https://example.invalid/demo.mp4'));
  bool fail = false;
  int disposals = 0;
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
    value = value.copyWith(isPlaying: true);
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
