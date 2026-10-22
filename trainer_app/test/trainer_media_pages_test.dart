import 'package:entrenaop_trainer/trainer_media_page.dart';
import 'package:entrenaop_trainer/trainer_media_repository.dart';
import 'package:entrenaop_trainer/trainer_technique_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

class MediaFixture extends TrainerMediaRepository {
  bool failFeedback = true;
  bool canFeedback = true;
  int feedbackCount = 0;
  final feedbacks = <(String, String, double, String)>[];
  TrainerMediaRow? resumed;
  final media = <TrainerMediaRow>[
    {
      'id': 'demo',
      'scope': 'trainer_exercise',
      'status': 'uploading',
      'source_bytes': 1024,
      'source_limit': 100 * 1024 * 1024,
      'duration_limit': 180,
      'reserved_bytes': 100 * 1024 * 1024,
      'created_at': '2026-10-21T10:00:00Z',
    },
  ];
  @override
  Future<List<TrainerMediaRow>> usage() async => [
    for (final scope in ['trainer_exercise', 'client_technique'])
      {
        'scope': scope,
        'asset_used': 1,
        'asset_limit': 100,
        'bytes_reserved': 100 * 1024 * 1024,
        'byte_limit': 2 * 1024 * 1024 * 1024,
        'source_limit': 100 * 1024 * 1024,
        'duration_limit': 180,
      },
  ];
  @override
  Future<List<TrainerMediaRow>> list({TrainerMediaRow? before}) async => media;
  @override
  ExerciseVideoSource source({TrainerMediaRow? resume}) {
    resumed = resume;
    return _Source();
  }

  @override
  Future<List<TrainerMediaRow>> technique(String assignmentId) async => [
    {
      'id': 'clip',
      'status': 'ready',
      'created_at': '2026-10-21T10:00:00Z',
      'duration_seconds': 90,
      'can_feedback': canFeedback,
      'feedback_count': feedbackCount,
      'feedback_limit': 100,
      'playback_url': 'https://fixture.b-cdn.net/video/play_720p.mp4',
      'feedback': [],
    },
  ];
  @override
  Future<void> feedback(
    String operation,
    String assetId,
    double second,
    String body,
  ) async {
    feedbacks.add((operation, assetId, second, body));
    if (failFeedback) {
      failFeedback = false;
      throw StateError('Respuesta perdida');
    }
  }
}

class _Source extends Fake implements ExerciseVideoSource {}

const readyUrl = 'https://fixture.b-cdn.net/library/play_720p.mp4';
TrainerMediaRow readyMedia({String url = readyUrl}) => {
  'id': 'ready-demo',
  'scope': 'trainer_exercise',
  'status': 'ready',
  'source_bytes': 1024,
  'reserved_bytes': 100 * 1024 * 1024,
  'created_at': '2026-10-21T11:00:00Z',
  'playback_url': url,
};

class PickerMediaFixture extends MediaFixture {
  int reservations = 0;
  @override
  ExerciseVideoSource source({TrainerMediaRow? resume}) => _PickerSource(this);
}

class _PickerSource extends Fake implements ExerciseVideoSource {
  _PickerSource(this.fixture);
  final PickerMediaFixture fixture;
  @override
  Future<ExerciseVideoUpload> create(int bytes) async {
    fixture.reservations++;
    return const ExerciseVideoUpload(id: 'unexpected', headers: {});
  }
}

void main() {
  testWidgets('vídeos ofrece acceso a técnica sin reproducir ni reservar', (
    tester,
  ) async {
    final fixture = PickerMediaFixture()..media.add(readyMedia());
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerMediaPage(
          repository: fixture,
          onOpenTechnique: () => opens++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Consultar técnica de alumnos'));
    await tester.tap(find.text('Consultar técnica de alumnos'));
    expect(opens, 1);
    expect(fixture.reservations, 0);
    await tester.scrollUntilVisible(find.textContaining('Listo ·'), 250);
    expect(find.textContaining('Listo ·'), findsOneWidget);
  });
  testWidgets(
    'selector reutiliza medios, ofrece solo listos válidos y no reserva',
    (tester) async {
      final fixture = PickerMediaFixture()
        ..media.addAll([
          readyMedia(),
          readyMedia(url: 'http://invalid.example/video.mp4'),
        ]);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showTrainerMediaPicker(context, fixture);
                },
                child: const Text('Elegir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      expect(find.byType(TrainerMediaPage), findsOneWidget);
      expect(find.text('Usar este vídeo'), findsOneWidget);
      expect(find.text('Subir demostración'), findsNothing);
      expect(find.text('Comprobar estado'), findsNothing);
      await tester.tap(find.text('Usar este vídeo'));
      await tester.pumpAndSettle();
      expect(selected, readyUrl);
      expect(fixture.reservations, 0);
      expect(find.byType(TrainerMediaPage), findsNothing);
    },
  );

  testWidgets('cancelar selector devuelve null y no reserva', (tester) async {
    final fixture = PickerMediaFixture()..media.add(readyMedia());
    String? selected = 'anterior';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showTrainerMediaPicker(context, fixture);
              },
              child: const Text('Elegir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancelar selección'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(fixture.reservations, 0);
  });

  testWidgets(
    'banco explica asignación y permite preparar ejercicio con vídeo existente',
    (tester) async {
      final fixture = PickerMediaFixture()..media.add(readyMedia());
      final chosen = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerMediaPage(
            repository: fixture,
            onCreateExercise: (url) async {
              chosen.add(url);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sesión asignada'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Crear ejercicio con este vídeo'),
        250,
      );
      await tester.ensureVisible(find.text('Crear ejercicio con este vídeo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ejercicio con este vídeo'));
      await tester.pumpAndSettle();
      expect(chosen, [readyUrl]);
      expect(fixture.reservations, 0);
    },
  );

  for (final expired in [true, false]) {
    testWidgets(
      'consulta histórica o cuota agotada no ofrece otra respuesta: inactivo=$expired',
      (tester) async {
        final fixture = MediaFixture()
          ..canFeedback = !expired
          ..feedbackCount = expired ? 0 : 100;
        await tester.pumpWidget(
          MaterialApp(
            home: TrainerTechniquePage(
              repository: fixture,
              assignmentId: 'assignment',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Añadir corrección en un instante'), findsNothing);
        expect(find.text('Reproducir vídeo'), findsOneWidget);
        expect(
          find.textContaining(
            expired ? 'Solo consulta:' : 'límite técnico de comentarios',
          ),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'medios explica presupuesto conservador y recupera reserva existente',
    (tester) async {
      final fixture = MediaFixture();
      await tester.pumpWidget(
        MaterialApp(home: TrainerMediaPage(repository: fixture)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Almacenamiento y límites'));
      await tester.tap(find.text('Almacenamiento y límites'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('El presupuesto puede agotarse antes'),
        findsNWidgets(2),
      );
      expect(find.text('Demostraciones propias'), findsOneWidget);
      expect(find.text('Técnica de alumnos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recuperar y continuar con el archivo original'),
        250,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Recuperar y continuar con el archivo original'),
      );
      await tester.pumpAndSettle();
      expect(fixture.resumed?['id'], 'demo');
      expect(find.text('Continuar reserva'), findsOneWidget);
      expect(find.text('Vídeo externo'), findsNothing);
    },
  );
  testWidgets('corrección temporal retiene payload y operación al reintentar', (
    tester,
  ) async {
    final fixture = MediaFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTechniquePage(
          repository: fixture,
          assignmentId: 'assignment',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir corrección en un instante'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '12,5');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Controla la bajada',
    );
    await tester.tap(find.text('Enviar corrección'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Reintenta con el mismo contenido'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enviar corrección'));
    await tester.pumpAndSettle();
    expect(fixture.feedbacks, hasLength(2));
    expect(fixture.feedbacks[0], fixture.feedbacks[1]);
    expect(fixture.feedbacks[0].$2, 'clip');
    expect(fixture.feedbacks[0].$3, 12.5);
  });
  testWidgets(
    'una reserva processing permite pedir revisión del original sin crear otra',
    (tester) async {
      final fixture = MediaFixture();
      fixture.media.single['status'] = 'processing';
      await tester.pumpWidget(
        MaterialApp(home: TrainerMediaPage(repository: fixture)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Revisar reserva y continuar'),
        250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar reserva y continuar'));
      await tester.pumpAndSettle();
      expect(fixture.resumed?['id'], 'demo');
      expect(find.text('Continuar reserva'), findsOneWidget);
      expect(find.text('Subir demostración privada'), findsNothing);
    },
  );
}
