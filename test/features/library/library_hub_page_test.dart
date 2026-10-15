import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final size in [const Size(320, 780), const Size(1100, 850)]) {
    testWidgets('Biblioteca cambia de contenido sin bajar a ${size.width}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: EntrenaTheme.dark, home: const LibraryHubPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesiones EntrenaOP').hitTestable(), findsOneWidget);
      expect(find.text('Mis sesiones'), findsOneWidget);
      expect(find.text('Explorar ejercicios').hitTestable(), findsNothing);

      await tester.tap(find.text('Ejercicios'));
      await tester.pumpAndSettle();
      expect(find.text('Ejercicios EntrenaOP').hitTestable(), findsOneWidget);
      expect(find.text('Mis ejercicios'), findsOneWidget);
      expect(find.text('Explorar sesiones').hitTestable(), findsNothing);
      await tester.ensureVisible(find.text('Crear ejercicio'));
      expect(find.text('Crear ejercicio').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Sesiones'));
      await tester.pumpAndSettle();
      expect(find.text('Sesiones EntrenaOP').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('deslizar cambia entre sesiones y ejercicios', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: EntrenaTheme.dark, home: const LibraryHubPage()),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(TabBarView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Ejercicios EntrenaOP').hitTestable(), findsOneWidget);
    await tester.fling(find.byType(TabBarView), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Sesiones EntrenaOP').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabe en móvil con el texto ampliado al doble', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const LibraryHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear sesión'));
    await tester.tap(find.text('Ejercicios'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear ejercicio'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada tarjeta abre su colección, incluida la personal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    final cases = [
      ('Sesiones', 'Explorar sesiones', '/plan/library', ''),
      ('Sesiones', 'Ver los míos', '/plan/library', 'personal'),
      ('Ejercicios', 'Explorar ejercicios', '/library/exercises', ''),
      ('Ejercicios', 'Ver los míos', '/library/exercises', 'personal'),
    ];
    for (final (section, label, path, tab) in cases) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      final finder = find.text(label).first;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['tab'] ?? '',
        tab,
      );
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'crear sesión ofrece ambos editores y guardar abre Mis sesiones',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear sesión'));
      await tester.tap(find.text('Crear sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Fuerza y acondicionamiento'), findsOneWidget);
      expect(find.text('Carrera'), findsOneWidget);
      await tester.tap(find.text('Carrera'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/plan/library/new-running',
      );
      await tester.tap(find.text('Guardar ejemplo'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/plan/library?tab=personal',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guardar un ejercicio abre Mis ejercicios; cancelar no navega', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ejercicios'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear ejercicio'));
    await tester.tap(find.text('Crear ejercicio'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/library');
    await tester.ensureVisible(find.text('Crear ejercicio'));
    await tester.tap(find.text('Crear ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar ejemplo'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/library/exercises?tab=personal',
    );
  });
}

GoRouter _router() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(path: '/library', builder: (_, _) => const LibraryHubPage()),
      GoRoute(
        path: '/plan/library',
        builder: (_, _) => const Scaffold(body: Text('Colección de sesiones')),
      ),
      GoRoute(
        path: '/library/exercises',
        builder: (_, _) =>
            const Scaffold(body: Text('Colección de ejercicios')),
      ),
      for (final path in [
        '/plan/library/new',
        '/plan/library/new-running',
        '/library/exercises/new',
      ])
        GoRoute(
          path: path,
          builder: (context, _) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop('created'),
                child: const Text('Guardar ejemplo'),
              ),
            ),
          ),
        ),
    ],
  );
}
