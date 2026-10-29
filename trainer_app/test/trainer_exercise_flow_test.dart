import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_media_pages_test.dart'
    show PickerMediaFixture, readyMedia, readyUrl;
import '../../packages/workout_editor_ui/test/exercise_labels_test.dart'
    show LabelsSource;

class ExerciseFixture extends TrainerExerciseRepository {
  bool fail = false;
  int limit = 500;
  final saves =
      <
        ({
          String operation,
          ExerciseFormSubmission<ExerciseDraft> submission,
          TrainerExercise? previous,
        })
      >[];
  List<TrainerExercise> rows = [];
  List<TrainerExercise> officialRows = [];
  bool failOfficial = false;
  @override
  Future<List<TrainerExercise>> officialCatalog() async {
    if (failOfficial) throw StateError('Conexión interrumpida');
    return officialRows;
  }

  @override
  Future<List<TrainerExercise>> list() async => rows;
  @override
  Future<TrainerExerciseUsage> usage() async => TrainerExerciseUsage.fromJson({
    'exercise_used': rows.length,
    'exercise_limit': limit,
    'image_used': 0,
    'image_limit': 1000,
  });
  @override
  Future<String> save(
    String operationId,
    ExerciseFormSubmission<ExerciseDraft> submission, {
    TrainerExercise? previous,
  }) async {
    saves.add((
      operation: operationId,
      submission: submission,
      previous: previous,
    ));
    if (fail) throw StateError('Conexión interrumpida');
    return 'saved';
  }
}

TrainerExercise entry(String id, {bool current = true}) =>
    TrainerExercise.fromJson({
      'id': id,
      'name': id,
      'version': 1,
      'current': current,
      'muscle_groups': ['espalda'],
      'equipment': ['barra'],
      'difficulty': 'inicial',
      'exercise_type': 'repeticiones',
    });

Future<void> open(WidgetTester tester, ExerciseFixture repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: TrainerExercisePage(
        repository: repository,
        access: FakeTrainerRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'colecciones filtran sin copiar ejercicios y distinguen los no agrupados',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ExerciseFixture()
        ..rows = [entry('Dominadas'), entry('Sentadillas')];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerExercisePage(
            repository: repo,
            access: FakeTrainerRepository(),
            preferences: LabelsSource(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Técnica (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Dominadas'), findsOneWidget);
      expect(find.text('Sentadillas'), findsNothing);
      await tester.tap(find.text('Sin colección (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Dominadas'), findsNothing);
      expect(find.text('Sentadillas'), findsOneWidget);
      expect(repo.saves, isEmpty);
    },
  );

  testWidgets(
    'fotos privadas y oficiales consultables sin editar ni consumir cuota',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ExerciseFixture()
        ..limit = 1
        ..rows = [
          TrainerExercise.fromJson({
            'id': 'private',
            'name': 'A-skips',
            'version': 2,
            'current': true,
            'thumbnail_url':
                'https://fixture.example.com/private.jpg?token=signed',
            'muscle_groups': ['piernas'],
            'equipment': [],
            'difficulty': 'inicial',
            'exercise_type': 'repeticiones',
          }),
        ]
        ..officialRows = [
          TrainerExercise.fromJson({
            'id': 'official',
            'name': 'Dominada oficial',
            'version': 1,
            'current': true,
            'thumbnail_url': 'https://fixture.example.com/public.jpg',
            'description': 'Sube sin balancearte.',
            'muscle_groups': ['espalda'],
            'equipment': ['barra'],
            'difficulty': 'intermedio',
            'exercise_type': 'repeticiones',
          }, official: true),
        ];
      await open(tester, repo);
      expect(
        tester.widget<ExerciseThumbnail>(find.byType(ExerciseThumbnail)).url,
        contains('token=signed'),
      );
      await tester.tap(find.text('A-skips'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Editar ejercicio'), findsNothing);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EntrenaOP'));
      await tester.pumpAndSettle();
      expect(find.text('Crear ejercicio privado'), findsNothing);
      expect(find.text('A-skips'), findsNothing);
      await tester.enterText(find.byType(TextField), 'barra');
      await tester.pumpAndSettle();
      expect(
        tester.widget<ExerciseThumbnail>(find.byType(ExerciseThumbnail)).url,
        endsWith('public.jpg'),
      );
      await tester.tap(find.text('Dominada oficial'));
      await tester.pumpAndSettle();
      expect(find.text('Sube sin balancearte.'), findsOneWidget);
      expect(
        find.text('Catálogo de EntrenaOP · Solo consulta'),
        findsOneWidget,
      );
      expect(find.byType(ExerciseForm), findsNothing);
      expect(find.text('Editar ejercicio'), findsNothing);
      expect(repo.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallo del catálogo permite reintentar y volver a privados', (
    tester,
  ) async {
    final repo = ExerciseFixture()
      ..rows = [entry('Propio')]
      ..failOfficial = true;
    await open(tester, repo);
    await tester.tap(find.text('EntrenaOP'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repo.failOfficial = false;
    repo.officialRows = [entry('Catálogo')];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo'), findsOneWidget);
    await tester.tap(find.text('Mis ejercicios'));
    await tester.pumpAndSettle();
    expect(find.text('Propio'), findsOneWidget);
  });

  testWidgets('la biblioteca propia encuentra ejercicios por etiquetas', (
    tester,
  ) async {
    final repo = ExerciseFixture()
      ..rows = [entry('Dominadas'), entry('Sentadillas')];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerExercisePage(
          repository: repo,
          access: FakeTrainerRepository(),
          preferences: LabelsSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Etiquetas: Dominadas'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tecnica');
    await tester.pumpAndSettle();
    expect(find.text('Dominadas'), findsOneWidget);
    expect(find.text('Sentadillas'), findsNothing);
  });

  testWidgets(
    'creador común vincula vídeo listo seleccionado sin subir ni guardar antes de confirmar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final exercises = ExerciseFixture();
      final media = PickerMediaFixture()..media.add(readyMedia());
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerExercisePage(
            repository: exercises,
            access: FakeTrainerRepository(),
            mediaRepository: media,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ejercicio privado'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-name')),
        'Vídeo propio reutilizado',
      );
      await tester.ensureVisible(find.text('Elegir vídeo de mi biblioteca'));
      await tester.tap(find.text('Elegir vídeo de mi biblioteca'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Usar este vídeo'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseForm), findsOneWidget);
      expect(exercises.saves, isEmpty);
      expect(media.reservations, 0);
      final video = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Vídeo externo'),
      );
      expect(video.controller!.text, readyUrl);
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-muscles')),
        'espalda',
      );
      await tester.ensureVisible(find.text('Crear ejercicio'));
      await tester.tap(find.text('Crear ejercicio'));
      await tester.pumpAndSettle();
      expect(exercises.saves.single.submission.draft.videoUrl, readyUrl);
      expect(
        exercises.saves.single.submission.draft.name,
        'Vídeo propio reutilizado',
      );
      expect(media.reservations, 0);
    },
  );

  testWidgets('el catálogo muestra versiones vigentes y permite buscarlas', (
    tester,
  ) async {
    final repo = ExerciseFixture()
      ..rows = [
        entry('Dominada propia'),
        entry('Versión anterior', current: false),
        entry('Flexión propia'),
      ];
    await open(tester, repo);
    expect(find.text('Dominada propia'), findsOneWidget);
    expect(find.text('Versión anterior'), findsNothing);
    await tester.enterText(find.byType(TextField), 'dominada');
    await tester.pumpAndSettle();
    expect(find.text('Flexión propia'), findsNothing);
    expect(find.textContaining('3/500 ejercicios'), findsOneWidget);
  });

  testWidgets(
    'reutiliza ExerciseForm y reintenta el mismo envío sin duplicar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ExerciseFixture()..fail = true;
      await open(tester, repo);
      await tester.tap(find.text('Crear ejercicio privado'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseForm), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-name')),
        'Dominada de ensayo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-muscles')),
        'espalda',
      );
      await tester.ensureVisible(find.text('Crear ejercicio'));
      await tester.tap(find.text('Crear ejercicio'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar el mismo guardado'), findsOneWidget);
      expect(repo.saves, hasLength(1));
      repo.fail = false;
      await tester.tap(find.text('Reintentar el mismo guardado'));
      await tester.pumpAndSettle();
      expect(repo.saves, hasLength(2));
      expect(repo.saves[0].operation, repo.saves[1].operation);
      expect(
        identical(repo.saves[0].submission, repo.saves[1].submission),
        isTrue,
      );
      expect(find.byType(ExerciseForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el cupo agotado impide empezar otro ejercicio', (tester) async {
    final repo = ExerciseFixture()
      ..rows = [entry('Último ejercicio')]
      ..limit = 1;
    await open(tester, repo);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear ejercicio privado'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Último ejercicio'), findsOneWidget);
  });

  testWidgets('biblioteca y formulario caben en móvil con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: TrainerExercisePage(
          repository: ExerciseFixture(),
          access: FakeTrainerRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Crear ejercicio privado'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Crear ejercicio privado'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseForm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
