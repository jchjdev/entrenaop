import 'package:entrenaop/features/workouts/data/services/client_technique_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_technique_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

class TechniqueFixture extends ClientTechniqueRepository {
  bool assigned = true, active = true, failShare = false;
  final shares = <(String, String, bool)>[];
  final rows = <ClientTechniqueClip>[];
  @override
  Future<ClientTechniqueContext?> context(String executionId) async => assigned
      ? ClientTechniqueContext.fromJson({
          'assignment_id': 'assignment',
          'execution_id': executionId,
          'can_upload': active,
          'source_limit': 100 * 1024 * 1024,
          'duration_limit': 180,
        })
      : null;
  @override
  Future<List<ClientTechniqueClip>> clips(String assignmentId) async => rows;
  @override
  ExerciseVideoSource uploader(
    ClientTechniqueContext context, {
    String? executionSetId,
    ClientTechniqueClip? resume,
  }) => _Source();
  @override
  Future<void> check(String clipId) async {}
  @override
  Future<void> setShared(String operation, String clipId, bool shared) async {
    shares.add((operation, clipId, shared));
    if (failShare) {
      failShare = false;
      throw StateError('Respuesta perdida');
    }
    rows.single['shared'] = shared;
  }
}

class _Source extends Fake implements ExerciseVideoSource {}

final execution = WorkoutExecution(
  id: 'execution',
  templateId: 'template',
  templateName: 'Sesión',
  templateVersion: 1,
  status: WorkoutExecutionStatus.completed,
  startedAt: DateTime(2026, 10, 21),
  sets: const [],
);

Widget app(TechniqueFixture fixture, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: WorkoutTechniqueSection(execution: execution, repository: fixture),
    ),
  ),
);

void main() {
  testWidgets('sin asignación profesional no aparece ninguna sección vacía', (
    tester,
  ) async {
    final fixture = TechniqueFixture()..assigned = false;
    await tester.pumpWidget(app(fixture));
    await tester.pumpAndSettle();
    expect(find.text('Técnica con tu preparador'), findsNothing);
    expect(find.text('Enviar vídeo de técnica'), findsNothing);
  });
  testWidgets(
    'alumno con pauta recibe subida contextual sin campo de URL externa',
    (tester) async {
      final fixture = TechniqueFixture();
      await tester.pumpWidget(app(fixture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar vídeo de técnica'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar técnica al preparador'), findsOneWidget);
      expect(find.text('Vídeo externo'), findsNothing);
      expect(find.textContaining('180 segundos'), findsOneWidget);
      expect(find.text('Subir vídeo'), findsOneWidget);
    },
  );
  testWidgets(
    'baja conserva respuestas y retirada reintenta la misma operación',
    (tester) async {
      final fixture = TechniqueFixture()
        ..active = false
        ..failShare = true;
      fixture.rows.add({
        'id': 'clip',
        'status': 'ready',
        'shared': true,
        'playback_url': 'https://fixture.b-cdn.net/video/play_720p.mp4',
        'created_at': '2026-10-21T10:00:00Z',
        'feedback': [
          {'second': 12.5, 'body': 'Controla la bajada'},
        ],
      });
      await tester.pumpWidget(app(fixture));
      await tester.pumpAndSettle();
      expect(find.text('Enviar vídeo de técnica'), findsNothing);
      expect(find.textContaining('Controla la bajada'), findsOneWidget);
      await tester.ensureVisible(find.text('Retirar compartición'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar compartición'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retirar compartición'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar compartición'));
      await tester.pumpAndSettle();
      expect(fixture.shares, hasLength(2));
      expect(fixture.shares[0].$1, fixture.shares[1].$1);
      expect(fixture.shares.every((s) => s.$2 == 'clip' && !s.$3), isTrue);
      expect(find.text('Volver a compartir'), findsOneWidget);
      expect(find.textContaining('Controla la bajada'), findsOneWidget);
    },
  );
  testWidgets('sección y modal caben en móvil con texto al doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(TechniqueFixture(), scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar vídeo de técnica'));
    await tester.tap(find.text('Enviar vídeo de técnica'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
