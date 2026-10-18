import 'dart:typed_data';

import 'package:entrenaop_admin/features/exercises/data/admin_exercise_video_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercise_video_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _Videos implements AdminExerciseVideoRepository {
  AdminVideoStatus result = const AdminVideoStatus('processing');
  var creates = 0;
  var uploads = 0;
  var thumbnails = 0;
  @override
  Future<AdminVideoUpload> create(int bytes) async {
    creates++;
    return const AdminVideoUpload(id: 'asset', headers: {});
  }

  @override
  Future<void> upload(
    AdminVideoUpload upload,
    Uint8List bytes,
    String contentType,
    void Function(double) progress,
  ) async {
    uploads++;
    progress(1);
  }

  @override
  Future<AdminVideoStatus> status(String id) async => result;
  @override
  Future<Uri> playback(String url) async => Uri.parse(url);
  @override
  Future<Uint8List> thumbnail(String url) async {
    thumbnails++;
    throw StateError('Sin portada');
  }
}

void main() {
  testWidgets(
    'fallar la portada no pierde el vídeo listo y permite reintentar',
    (tester) async {
      final videos = _Videos()
        ..result = const AdminVideoStatus(
          'ready',
          'https://fixture.b-cdn.net/video/play_360p.mp4',
        );
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final busy = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminExerciseVideoField(
              controller: controller,
              repository: videos,
              onBusyChanged: busy.add,
              onCoverReady: (_, _) =>
                  throw StateError('No debe recibir portada inválida'),
              pickVideo: () async =>
                  XFile.fromData(Uint8List.fromList([1]), name: 'clip.mp4'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Subir vídeo'));
      await tester.pumpAndSettle();
      expect(controller.text, videos.result.url);
      expect(videos.thumbnails, 1);
      expect(busy.last, false);
      await tester.tap(find.text('Usar portada del vídeo'));
      await tester.pumpAndSettle();
      expect(videos.thumbnails, 2);
      expect(videos.uploads, 1);
      expect(busy.last, false);
    },
  );
  testWidgets(
    'fallar el selector no pierde el anterior ni deja bloqueado el guardado',
    (tester) async {
      final videos = _Videos();
      final controller = TextEditingController(
        text: 'https://previous.invalid/clip.mp4',
      );
      addTearDown(controller.dispose);
      final busy = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminExerciseVideoField(
              controller: controller,
              repository: videos,
              onBusyChanged: busy.add,
              pickVideo: () async => throw StateError('Selector no disponible'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sustituir vídeo'));
      await tester.pumpAndSettle();
      expect(controller.text, 'https://previous.invalid/clip.mp4');
      expect(videos.creates, 0);
      expect(busy.last, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'conserva el anterior hasta ready y reconsulta sin duplicar subida',
    (tester) async {
      final videos = _Videos();
      final controller = TextEditingController(
        text: 'https://previous.invalid/clip.mp4',
      );
      addTearDown(controller.dispose);
      final busy = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminExerciseVideoField(
              controller: controller,
              repository: videos,
              onBusyChanged: busy.add,
              pickVideo: () async => XFile.fromData(
                Uint8List.fromList([1, 2, 3]),
                name: 'clip.mp4',
                mimeType: 'video/mp4',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sustituir vídeo'));
      await tester.pumpAndSettle();
      expect(controller.text, 'https://previous.invalid/clip.mp4');
      expect(busy.last, true);
      videos.result = const AdminVideoStatus(
        'ready',
        'https://fixture.b-cdn.net/new/play_720p.mp4',
      );
      await tester.tap(find.text('Comprobar vídeo'));
      await tester.pumpAndSettle();
      expect(controller.text, 'https://fixture.b-cdn.net/new/play_720p.mp4');
      expect(videos.creates, 1);
      expect(videos.uploads, 1);
      expect(busy.last, false);
    },
  );
  testWidgets('rechazo conserva el vídeo anterior y libera el guardado', (
    tester,
  ) async {
    final videos = _Videos()..result = const AdminVideoStatus('rejected');
    final controller = TextEditingController(
      text: 'https://previous.invalid/clip.mp4',
    );
    addTearDown(controller.dispose);
    final busy = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminExerciseVideoField(
            controller: controller,
            repository: videos,
            onBusyChanged: busy.add,
            pickVideo: () async =>
                XFile.fromData(Uint8List.fromList([1]), name: 'clip.mp4'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sustituir vídeo'));
    await tester.pumpAndSettle();
    expect(controller.text, 'https://previous.invalid/clip.mp4');
    expect(find.textContaining('Vídeo rechazado'), findsOneWidget);
    expect(busy.last, false);
  });
}
