import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_core/exercise_draft.dart';

class _Source extends Fake implements ExerciseVideoSource {
  int creates = 0;
  @override
  Future<ExerciseVideoUpload> create(int bytes) async {
    creates++;
    return const ExerciseVideoUpload(id: 'private-adapter-ticket', headers: {});
  }
}

void main() {
  testWidgets(
    'un consumidor sin ADMIN conserva enlace externo y subida a la vez',
    (tester) async {
      final source = _Source();
      TextEditingController? controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseForm(
              title: 'Ejercicio privado',
              supportingText: 'Solo contenido autorizado',
              submitLabel: 'Guardar',
              onSubmit: (_) {},
              initialDraft: const ExerciseDraft(
                name: 'Ejercicio',
                muscleGroups: ['espalda'],
                equipment: [],
                difficulty: 'inicial',
                exerciseType: 'repeticiones',
                videoUrl: 'https://external.invalid/technique.mp4',
              ),
              videoFieldBuilder: (value, busy, cover) {
                controller = value;
                return ExerciseVideoField(
                  controller: value,
                  repository: source,
                  onBusyChanged: busy,
                  pickVideo: () async => null,
                );
              },
            ),
          ),
        ),
      );
      expect(
        find.widgetWithText(TextFormField, 'Vídeo externo'),
        findsOneWidget,
      );
      expect(find.text('Sustituir vídeo'), findsOneWidget);
      await tester.ensureVisible(find.text('Sustituir vídeo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sustituir vídeo'));
      await tester.pumpAndSettle();
      expect(controller!.text, 'https://external.invalid/technique.mp4');
      expect(source.creates, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Vídeo externo'),
        'https://external.invalid/other.mp4',
      );
      expect(controller!.text, 'https://external.invalid/other.mp4');
    },
  );

  testWidgets(
    'el límite inyectado rechaza el archivo antes de llamar al proveedor',
    (tester) async {
      final source = _Source();
      final controller = TextEditingController(
        text: 'https://external.invalid/keep.mp4',
      );
      addTearDown(controller.dispose);
      final busy = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseVideoField(
              controller: controller,
              repository: source,
              onBusyChanged: busy.add,
              maxVideoBytes: 1,
              maxVideoDurationSeconds: 30,
              pickVideo: () async =>
                  XFile.fromData(Uint8List.fromList([1, 2]), name: 'clip.mp4'),
            ),
          ),
        ),
      );
      expect(find.textContaining('30 segundos'), findsOneWidget);
      await tester.tap(find.text('Sustituir vídeo'));
      await tester.pumpAndSettle();
      expect(source.creates, 0);
      expect(busy.last, isFalse);
      expect(controller.text, 'https://external.invalid/keep.mp4');
      expect(find.textContaining('como máximo'), findsWidgets);
    },
  );
}
