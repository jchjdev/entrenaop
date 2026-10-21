import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Widget app(
  PreviewSource source, [
  String url = 'https://fixture.b-cdn.net/one/play_720p.mp4',
]) => MaterialApp(
  home: Scaffold(
    body: ExerciseVideoPreview(url: url, source: source),
  ),
);

void main() {
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
