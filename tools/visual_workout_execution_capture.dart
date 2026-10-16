// Capturas del ejecutor real con datos ficticios y una imagen local de referencia.
// No consulta cuentas, Supabase ni el catálogo publicado.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';

import '../test/helpers/memory_workout_session_draft_store.dart';

void main() {
  for (final (name, timed, width, height, scale) in [
    ('repeticiones', false, 390.0, 844.0, 1.0),
    ('tiempo', true, 390.0, 844.0, 1.0),
    ('tiempo-iphone-texto', true, 390.0, 844.0, 1.2),
    ('tiempo-alto', true, 412.0, 915.0, 1.0),
    ('tiempo-ampliado', true, 320.0, 700.0, 2.0),
    ('estrecho', false, 320.0, 844.0, 2.0),
    ('escritorio', false, 1000.0, 844.0, 1.0),
  ]) {
    testWidgets('captura $name', (t) async {
      t.view.physicalSize = Size(width, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      if (width < 600) {
        t.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(t.view.resetPadding);
      }
      await t.runAsync(() async {
        const fonts =
            '/workspace/toolchains/flutter/bin/cache/artifacts/material_fonts';
        for (final (family, file) in [
          ('Roboto', 'Roboto-Regular.ttf'),
          ('MaterialIcons', 'MaterialIcons-Regular.otf'),
        ]) {
          final bytes = await File('$fonts/$file').readAsBytes();
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      });
      final imagePath = Platform.environment['WORKOUT_CAPTURE_IMAGE'];
      if (imagePath != null) {
        final bytes = (await t.runAsync(() => File(imagePath).readAsBytes()))!;
        debugNetworkImageHttpClientProvider = () => _ImageClient(bytes);
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
      }
      final repository = _Workouts(
        timed,
        includeInstructions:
            name != 'tiempo-iphone-texto' && name != 'tiempo-alto',
      );
      final timer = _TimerStore();
      final cues = _Cues();
      final cubit = ActiveWorkoutCubit(
        executionId: 'preview',
        sessionDraftStore: MemoryWorkoutSessionDraftStore(),
        getExercise: GetExerciseByIdUseCase(_Exercises(imagePath != null)),
        getExecution: GetWorkoutExecutionUseCase(repository),
        completeSet: CompleteWorkoutSetUseCase(repository),
        completeAmrap: CompleteAmrapBlockUseCase(repository),
        correctSet: CorrectWorkoutSetUseCase(repository),
        skipSet: SkipWorkoutSetUseCase(repository),
        finishExecution: FinishWorkoutExecutionUseCase(repository),
        abandonExecution: AbandonWorkoutExecutionUseCase(repository),
        discardExecution: DiscardWorkoutExecutionUseCase(repository),
        getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(
          repository,
        ),
        timerStore: timer,
        cueService: cues,
      );
      await cubit.load();
      final boundaryKey = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BlocProvider.value(
              value: cubit,
              child: ActiveWorkoutPage(timerStore: timer, cueService: cues),
            ),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      if (timed && scale <= 1.2) {
        final timerBottom = t
            .getBottomRight(find.byType(WorkoutSetCountdown))
            .dy;
        final finishTop = t.getTopLeft(find.text('Terminar serie')).dy;
        expect(timerBottom, lessThan(finishTop));
        expect(find.text('Iniciar temporizador').hitTestable(), findsOneWidget);
      }
      await _capture(t, boundaryKey, name);
      if (name == 'repeticiones') {
        await t.tap(find.byTooltip('Técnica del ejercicio'));
        await t.pumpAndSettle();
        expect(find.text('Editar ejercicio'), findsNothing);
        await _capture(t, boundaryKey, 'tecnica');
        await t.tap(find.byTooltip('Cerrar detalle'));
        await t.pumpAndSettle();
        await t.tap(find.text('Terminar serie'));
        await t.pumpAndSettle();
        await _capture(t, boundaryKey, 'descanso');
        await t.tap(find.textContaining('Series y registros').last);
        await t.pumpAndSettle();
        await _capture(t, boundaryKey, 'registros');
        await t.tap(find.textContaining('Datos por confirmar').first);
        await t.pumpAndSettle();
        await _capture(t, boundaryKey, 'editar');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _capture(t, boundaryKey, 'teclado');
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Cerrar resultado'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Cerrar registros'));
        await t.pumpAndSettle();
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 61));
      expect(t.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
      await cubit.close();
    });
  }
}

Future<void> _capture(WidgetTester t, GlobalKey key, String name) async {
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final shot = await boundary.toImage(pixelRatio: 2);
    final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/workout-execution-preview')
      ..createSync(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    shot.dispose();
  });
}

class _Workouts implements WorkoutRepository {
  _Workouts(bool timed, {bool includeInstructions = true})
    : execution = WorkoutExecution(
        id: 'preview',
        templateId: 'template',
        templateName: timed
            ? 'Fuerza · Control isométrico'
            : 'Fuerza · Tren superior',
        templateVersion: 1,
        status: WorkoutExecutionStatus.inProgress,
        startedAt: DateTime.utc(2026, 10, 15),
        sets: [
          for (var i = 0; i < 3; i++)
            WorkoutExecutionSet(
              id: 'set-$i',
              blockOrder: 0,
              blockName: 'Principal',
              blockFormat: WorkoutBlockFormat.straightSets,
              itemOrder: 0,
              exerciseId: 'exercise',
              exerciseName: 'Dominada isométrica',
              exerciseDescription: 'Mantén la barbilla a la altura de la barra y controla la posición.',
              itemInstructions: includeInstructions
                  ? 'Mantén el cuerpo estable.'
                  : null,
              setOrder: i,
              targetReps: timed ? null : 8,
              targetDurationSeconds: timed ? 20 : null,
              targetRir: 2,
              restAfterSeconds: 45,
              status: WorkoutSetStatus.pending,
            ),
        ],
      );
  WorkoutExecution execution;
  @override
  Future<WorkoutExecution?> getExecution(String id) async => execution;
  @override
  Future<int> getPendingMutationCount() async => 0;
  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async => WorkoutMutationDisposition.synced;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exercises implements ExerciseRepository {
  _Exercises(this.hasImage);
  final bool hasImage;
  @override
  Future<ExerciseEntity?> getExerciseById(String id) async => ExerciseEntity(
    id: id,
    name: 'Dominada isométrica',
    description: 'Mantén una posición estable y controlada.',
    thumbnailUrl: hasImage ? 'https://preview.invalid/exercise.jpg' : null,
    muscleGroups: const ['Dorsales', 'Bíceps'],
    equipment: const ['Barra de dominadas'],
    difficulty: 'Media',
    exerciseType: 'strength',
    isPublic: true,
    origin: ExerciseOrigin.system,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TimerStore implements WorkoutTimerStore {
  final values = <String, WorkoutTimerSnapshot>{};
  @override
  Future<WorkoutTimerSnapshot?> read(String id) async => values[id];
  @override
  Future<void> write(String id, WorkoutTimerSnapshot snapshot) async {
    values[id] = snapshot;
  }

  @override
  Future<void> clear(String id) async {
    values.remove(id);
  }
}

class _Cues implements WorkoutCueService {
  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();
  @override
  Future<bool> shouldOfferHapticsPermission() async => false;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> signal(WorkoutCue cue) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageClient implements HttpClient {
  _ImageClient(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async => _ImageRequest(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
