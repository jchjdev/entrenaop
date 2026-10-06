import 'dart:async';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'busca por músculo sin tildes y combina opciones reales del catálogo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1150));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var reads = 0;
      final catalog = [
        const ExerciseEntity(
          id: 'pull',
          name: 'Dominadas',
          description: 'Trabajo controlado.',
          muscleGroups: ['espalda', 'bíceps'],
          equipment: ['barra'],
          difficulty: 'intermedio',
          exerciseType: 'repeticiones',
          isPublic: true,
          origin: ExerciseOrigin.system,
        ),
        const ExerciseEntity(
          id: 'hold',
          name: 'Plancha',
          muscleGroups: ['core'],
          equipment: ['peso corporal'],
          difficulty: 'inicial',
          exerciseType: 'duración',
          isPublic: true,
          origin: ExerciseOrigin.system,
        ),
        _exercise('Mi ejercicio', owner: 'me'),
      ];
      await tester.pumpWidget(
        _app(
          load: () async {
            reads++;
            return catalog;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'BICEPS');
      await tester.pumpAndSettle();
      expect(find.text('Dominadas'), findsOneWidget);
      expect(find.text('Plancha'), findsNothing);
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Espalda').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiempo').last);
      await tester.pumpAndSettle();
      expect(
        find.text('No hay ejercicios que coincidan con tu búsqueda.'),
        findsOneWidget,
      );
      expect(find.text('Filtros (2)'), findsOneWidget);
      await tester.tap(find.text('Mis ejercicios'));
      await tester.pumpAndSettle();
      expect(find.text('Mi ejercicio'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('EntrenaOP'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'BICEPS',
      );
      await tester.tap(find.text('Limpiar búsqueda y filtros').first);
      await tester.pumpAndSettle();
      expect(find.text('Dominadas'), findsOneWidget);
      expect(find.text('Plancha'), findsOneWidget);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('los cuatro filtros se adaptan a 320 px con texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(load: () async => _catalog, scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(4));
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'EntrenaOP no mezcla ejercicios propios, ajenos o privados del sistema',
    (tester) async {
      await tester.pumpWidget(_app(load: () async => _catalog));
      await tester.pumpAndSettle();
      expect(find.text('Sentadilla oficial'), findsOneWidget);
      for (final name in [
        'Mi ejercicio',
        'Ejercicio ajeno',
        'Sistema privado',
      ]) {
        expect(find.text(name), findsNothing);
      }
      await tester.tap(find.text('Sentadilla oficial'));
      await tester.pumpAndSettle();
      expect(find.text('Grupos musculares'), findsOneWidget);
      expect(find.text('piernas'), findsOneWidget);
      expect(find.text('Material'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mis ejercicios abre directamente solo los ejercicios de la cuenta',
    (tester) async {
      await tester.pumpWidget(_app(load: () async => _catalog, personal: true));
      await tester.pumpAndSettle();
      expect(find.text('Mi ejercicio'), findsOneWidget);
      expect(find.text('Sentadilla oficial'), findsNothing);
      expect(find.text('Ejercicio ajeno'), findsNothing);
      expect(find.text('Crear ejercicio'), findsOneWidget);
    },
  );

  testWidgets('vacío personal conserva un botón explícito para crear', (
    tester,
  ) async {
    await tester.pumpWidget(_app(load: () async => [], personal: true));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Todavía no has creado ejercicios.'),
      findsOneWidget,
    );
    expect(find.text('Crear ejercicio'), findsOneWidget);
  });

  testWidgets('un fallo permite reintentar la lectura sin escribir datos', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      _app(
        load: () async {
          if (++reads == 1) throw StateError('offline');
          return _catalog;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hemos podido cargar los ejercicios.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Sentadilla oficial'), findsOneWidget);
    expect(reads, 2);
  });

  testWidgets(
    'cambiar de cuenta ignora una lectura anterior todavía pendiente',
    (tester) async {
      final old = Completer<List<ExerciseEntity>>();
      final next = Completer<List<ExerciseEntity>>();
      await tester.pumpWidget(_app(load: () => old.future, personal: true));
      await tester.pump();
      await tester.pumpWidget(
        _app(load: () => next.future, personal: true, userId: 'other'),
      );
      next.complete([_exercise('Nueva cuenta', owner: 'other')]);
      await tester.pumpAndSettle();
      old.complete(_catalog);
      await tester.pumpAndSettle();
      expect(find.text('Nueva cuenta'), findsOneWidget);
      expect(find.text('Mi ejercicio'), findsNothing);
    },
  );

  testWidgets(
    'guardar desde el navegador recarga y selecciona Mis ejercicios',
    (tester) async {
      var reads = 0;
      final router = GoRouter(
        initialLocation: '/library/exercises',
        routes: [
          GoRoute(
            path: '/library/exercises',
            builder: (_, _) => _provider(
              load: () async {
                reads++;
                return reads == 1
                    ? _catalog
                    : [..._catalog, _exercise('Recién creado', owner: 'me')];
              },
            ),
          ),
          GoRoute(
            path: '/library/exercises/new',
            builder: (context, _) => Scaffold(
              body: FilledButton(
                onPressed: () => context.pop('created'),
                child: const Text('Guardar'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis ejercicios'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No coincide con el nuevo ejercicio');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Recién creado'), findsOneWidget);
      expect(find.text('Sentadilla oficial'), findsNothing);
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lista y detalle caben a 320 px con texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(load: () async => _catalog, scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sentadilla oficial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentadilla oficial'));
    await tester.pumpAndSettle();
    expect(find.text('Grupos musculares'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required Future<List<ExerciseEntity>> Function() load,
  bool personal = false,
  String userId = 'me',
  double scale = 1,
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: _provider(load: load, userId: userId, personal: personal),
);

Widget _provider({
  required Future<List<ExerciseEntity>> Function() load,
  String userId = 'me',
  bool personal = false,
}) => BlocProvider(
  key: ValueKey(userId),
  create: (_) => ExerciseLibraryCubit(
    getExercises: GetExercisesUseCase(_Repository(load)),
    userId: userId,
  )..load(),
  child: ExerciseLibraryPage(initialPersonalTab: personal),
);

class _Repository implements ExerciseRepository {
  _Repository(this.load);
  final Future<List<ExerciseEntity>> Function() load;
  @override
  Future<List<ExerciseEntity>> getExercises() => load();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExerciseEntity _exercise(String name, {String? owner, bool public = false}) =>
    ExerciseEntity(
      id: name,
      name: name,
      description: 'Descripción del movimiento.',
      muscleGroups: const ['piernas'],
      equipment: const ['mancuernas'],
      difficulty: 'beginner',
      exerciseType: 'strength',
      isPublic: public,
      origin: owner == null ? ExerciseOrigin.system : ExerciseOrigin.user,
      createdBy: owner,
    );
final _catalog = [
  _exercise('Sentadilla oficial', public: true),
  _exercise('Sistema privado'),
  _exercise('Mi ejercicio', owner: 'me'),
  _exercise('Ejercicio ajeno', owner: 'other', public: true),
];
