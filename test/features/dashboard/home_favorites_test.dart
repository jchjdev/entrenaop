import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_favorites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Repository repository, {
    Future<void> Function(String)? onOpen,
    double scale = 1,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: HomeFavorites(
              repository: repository,
              userId: 'user-a',
              onOpen: onOpen ?? (_) async {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: EntrenaTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder checkbox(HomeShortcut item) =>
      find.widgetWithText(CheckboxListTile, item.label);

  testWidgets('quitar y ordenar favoritos persiste al volver a abrir', (
    tester,
  ) async {
    final repository = _Repository();
    await mount(tester, repository);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(checkbox(HomeShortcut.personalSessions));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Subir Disponibilidad'));
    await tester.tap(find.byTooltip('Subir Disponibilidad'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar favoritos'));
    await tester.tap(find.text('Guardar favoritos'));
    await tester.pumpAndSettle();
    expect(repository.savedUser, 'user-a');
    expect(repository.items, [
      HomeShortcut.availability,
      HomeShortcut.personalExercises,
    ]);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, repository);
    expect(find.text('Mis sesiones'), findsNothing);
    expect(find.text('Mis ejercicios'), findsOneWidget);
  });
  testWidgets(
    'el selector no ofrece duplicados y cancelar conserva la selección',
    (tester) async {
      final repository = _Repository();
      await mount(tester, repository);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(10));
      for (final label in [
        'Mi semana',
        'Marcas y pruebas',
        'Ritmos de carrera',
        'PAEF / PAFAS',
        'Biblioteca',
        'Crear ejercicio',
      ]) {
        expect(find.widgetWithText(CheckboxListTile, label), findsNothing);
      }
      await tester.tap(checkbox(HomeShortcut.personalExercises));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(checkbox(HomeShortcut.personalExercises))
            .value,
        isFalse,
      );
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.items, defaultHomeFavorites);
      expect(repository.savedUser, isNull);
    },
  );
  testWidgets('un fallo al guardar conserva los accesos anteriores', (
    tester,
  ) async {
    final repository = _Repository()..failSave = true;
    await mount(tester, repository);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(checkbox(HomeShortcut.personalSessions));
    await tester.ensureVisible(find.text('Guardar favoritos'));
    await tester.tap(find.text('Guardar favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Mis sesiones'), findsOneWidget);
    expect(find.textContaining('Se conservan los anteriores'), findsOneWidget);
  });

  testWidgets(
    'añade un cuarto favorito de Preparador y rechaza un quinto sin perder el orden',
    (tester) async {
      final repository = _Repository();
      final opened = <String>[];
      await mount(
        tester,
        repository,
        onOpen: (route) async => opened.add(route),
      );
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(checkbox(HomeShortcut.trainerNotices));
      await tester.tap(checkbox(HomeShortcut.trainerNotices));
      await tester.pumpAndSettle();
      await tester.ensureVisible(checkbox(HomeShortcut.notifications));
      await tester.tap(checkbox(HomeShortcut.notifications));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(checkbox(HomeShortcut.notifications))
            .value,
        isFalse,
      );
      expect(find.textContaining('Puedes tener hasta cuatro'), findsOneWidget);
      await tester.ensureVisible(find.text('Guardar favoritos'));
      await tester.tap(find.text('Guardar favoritos'));
      await tester.pumpAndSettle();
      expect(repository.items, [
        ...defaultHomeFavorites,
        HomeShortcut.trainerNotices,
      ]);
      await tester.ensureVisible(find.text('Avisos del preparador'));
      await tester.tap(find.text('Avisos del preparador'));
      await tester.pumpAndSettle();
      expect(opened, ['/my-trainer?view=notices']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('los cuatro accesos y el editor caben a 320 px con letra doble', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository()
      ..items = [
        HomeShortcut.trainerNotices,
        HomeShortcut.trainerAppointments,
        HomeShortcut.connections,
        HomeShortcut.notifications,
      ];
    await mount(tester, repository, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(checkbox(HomeShortcut.connections));
    await tester.tap(checkbox(HomeShortcut.connections));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar favoritos'));
    await tester.tap(find.text('Guardar favoritos'));
    await tester.pumpAndSettle();
    expect(repository.items, [
      HomeShortcut.trainerNotices,
      HomeShortcut.trainerAppointments,
      HomeShortcut.notifications,
    ]);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements HomeFavoritesRepository {
  List<HomeShortcut> items = List.of(defaultHomeFavorites);
  String? savedUser;
  bool failSave = false;
  @override
  Future<List<HomeShortcut>> load(String userId) async => List.of(items);
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {
    if (failSave) throw StateError('No storage');
    savedUser = userId;
    items = List.of(favorites);
  }
}
