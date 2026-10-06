import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_favorites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> mount(WidgetTester tester, _Repository repository) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: HomeFavorites(
              repository: repository,
              userId: 'user-a',
              onOpen: (_) async {},
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
    await tester.tap(checkbox(HomeShortcut.week));
    await tester.pumpAndSettle();
    await tester.tap(checkbox(HomeShortcut.runningPace));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Subir Ritmos de carrera'));
    await tester.tap(find.byTooltip('Subir Ritmos de carrera'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar favoritos'));
    await tester.tap(find.text('Guardar favoritos'));
    await tester.pumpAndSettle();
    expect(repository.savedUser, 'user-a');
    expect(repository.items, [
      HomeShortcut.personalSessions,
      HomeShortcut.marks,
      HomeShortcut.runningPace,
      HomeShortcut.availability,
    ]);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, repository);
    expect(find.text('Mi semana'), findsNothing);
    expect(find.text('Ritmos de carrera'), findsOneWidget);
  });
  testWidgets('cancelar y superar el máximo no alteran lo guardado', (
    tester,
  ) async {
    final repository = _Repository();
    await mount(tester, repository);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(checkbox(HomeShortcut.runningPace));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(checkbox(HomeShortcut.runningPace)).value,
      isFalse,
    );
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.items, defaultHomeFavorites);
    expect(repository.savedUser, isNull);
  });
  testWidgets('un fallo al guardar conserva los accesos anteriores', (
    tester,
  ) async {
    final repository = _Repository()..failSave = true;
    await mount(tester, repository);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(checkbox(HomeShortcut.week));
    await tester.ensureVisible(find.text('Guardar favoritos'));
    await tester.tap(find.text('Guardar favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Mi semana'), findsOneWidget);
    expect(find.textContaining('Se conservan los anteriores'), findsOneWidget);
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
