import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/navigation/app_account_actions.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('campana abre Avisos y selecciona Preparador', (tester) async {
    final router = _createRouter(unread: 2);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('2 avisos sin leer'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/my-trainer');
    expect(router.state.uri.queryParameters['view'], 'notices');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
  });
  testWidgets(
    'sin preparador quedan cuatro destinos y Perfil sigue accesible arriba',
    (tester) async {
      final router = _createRouter(hasTrainer: false);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(4),
      );
      expect(find.text('Preparador'), findsNothing);
      expect(find.text('Perfil'), findsNothing);
      await tester.tap(find.byTooltip('Mi perfil'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('etiquetas completas y separadas: $width px, texto $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = _createRouter();
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
        for (final selected in ['Biblioteca', 'Evolución']) {
          await tester.tap(find.text(selected));
          await tester.pumpAndSettle();
          Rect? previous;
          for (final label in [
            'Inicio',
            'Mi plan',
            'Biblioteca',
            'Evolución',
            'Preparador',
          ]) {
            final finder = find.text(label);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            );
            expect(
              boxes,
              hasLength(1),
              reason: '$label debe quedar en una línea',
            );
            final rect = tester.getRect(finder);
            if (previous != null) {
              expect(rect.left - previous.right, greaterThanOrEqualTo(12));
            }
            previous = rect;
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('usa la barra inferior y cambia de sección en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Mi plan'));
    await tester.pumpAndSettle();

    expect(find.text('Contenido de Mi plan'), findsOneWidget);
    expect(router.state.matchedLocation, '/plan');
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/library');
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    expect(bar.selectedIndex, 2);
    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/profile');
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/library');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('usa navegación lateral en pantallas amplias', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  for (final width in [390.0, 1000.0]) {
    testWidgets('conserva sección y segundo toque vuelve a raíz: $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = _createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/my-trainer/detail');
      await tester.pumpAndSettle();
      expect(find.text('Detalle de Preparador'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/my-trainer/detail');
      expect(find.text('Detalle de Preparador'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.people));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/my-trainer');
      expect(find.text('Contenido de Preparador'), findsOneWidget);
      expect(find.text('Detalle de Preparador'), findsNothing);
    });
  }
}

GoRouter _createRouter({bool hasTrainer = true, int unread = 0}) {
  final controller = StudentNavigationController(
    loadSnapshot: () async => const StudentNoticeSnapshot(
      items: [],
      hasMore: false,
      unreadCount: 0,
      resources: StudentNoticeResources(),
    ),
    loadHasRelationship: () async => hasTrainer,
  )..hasRelationship = hasTrainer;
  controller.acceptSnapshot(
    StudentNoticeSnapshot(
      items: const [],
      hasMore: false,
      unreadCount: unread,
      resources: const StudentNoticeResources(),
    ),
  );
  addTearDown(controller.dispose);
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => StudentNavigationScope(
          controller: controller,
          child: AppShell(navigationShell: navigationShell),
        ),
        branches: [
          _branch('/home', 'Inicio'),
          _branch('/plan', 'Mi plan'),
          _branch('/library', 'Biblioteca'),
          _branch('/assessment/history', 'Evolución'),
          _branch('/my-trainer', 'Preparador'),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: context.pop)),
          body: const Text('Contenido de Perfil'),
        ),
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, String name) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: name == 'Perfil'
                ? BackButton(onPressed: context.pop)
                : null,
            actions: const [AppAccountActions()],
          ),
          body: Center(child: Text('Contenido de $name')),
        ),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) =>
                Scaffold(body: Text('Detalle de $name')),
          ),
        ],
      ),
    ],
  );
}
