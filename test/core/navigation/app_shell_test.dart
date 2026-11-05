import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';

import '../../support/coach_workspace_fixture.dart' as coach;

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('separa avisos recibidos y actividad profesional: $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final received =
            StudentNavigationController(
              loadSnapshot: () async => const StudentNoticeSnapshot(
                items: [],
                hasMore: false,
                unreadCount: 7,
                resources: StudentNoticeResources(),
              ),
              loadHasRelationship: () async => true,
            )..acceptSnapshot(
              const StudentNoticeSnapshot(
                items: [],
                hasMore: false,
                unreadCount: 7,
                resources: StudentNoticeResources(),
              ),
            );
        addTearDown(received.dispose);
        final professional = coach.FakeCoach();
        final router = coach.createRouter(
          professional,
          coach.FakeSecurity(),
          initial: '/profile',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => StudentNavigationScope(
              controller: received,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Perfil · 2 novedades en tu espacio de preparador'),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(
            RegExp('2 novedades en tu espacio de preparador'),
          ),
          findsWidgets,
        );
        expect(find.text('7'), findsWidgets);
        expect(
          find.byKey(const ValueKey('app-workspace-switcher')),
          findsNothing,
        );
        expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
        final controller = CoachWorkspaceScope.of(
          tester.element(find.text('Perfil personal')),
        ).controller;
        professional.enabled = false;
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Perfil · 2 novedades en tu espacio de preparador'),
          findsNothing,
        );
        expect(find.text('Entrar como preparador'), findsNothing);
        expect(find.text('7'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'avisos en Preparador y cuenta en Perfil, sin acciones superiores',
    (tester) async {
      final router = _createRouter(unread: 2);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byTooltip('Mi perfil'), findsNothing);
      await tester.tap(find.byTooltip('Preparador · 2 novedades sin leer'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my-trainer');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      // Entrar en la sección no confirma lecturas. El indicador sigue el total
      // autoritativo cuando el servidor informa después de la lectura real.
      expect(find.text('2'), findsWidgets);
      final controller = tester
          .widget<StudentNavigationScope>(find.byType(StudentNavigationScope))
          .notifier!;
      controller.acceptSnapshot(
        const StudentNoticeSnapshot(
          items: [],
          hasMore: false,
          unreadCount: 0,
          resources: StudentNoticeResources(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(find.byTooltip('Preparador · 2 novedades sin leer'), findsNothing);
      expect(router.state.uri.path, '/my-trainer');
    },
  );
  testWidgets(
    'sin vínculo Preparador permite descubrir profesionales y Perfil sigue accesible',
    (tester) async {
      final router = _createRouter(hasTrainer: false);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(5),
      );
      expect(find.text('Preparador'), findsOneWidget);
      await tester.tap(find.text('Preparador'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my-trainer');
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text('Inicio'));
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
        for (final selected in ['Biblioteca', 'Perfil']) {
          await tester.tap(find.text(selected));
          await tester.pumpAndSettle();
          Rect? previous;
          for (final label in [
            'Inicio',
            'Biblioteca',
            'Entrena',
            'Preparador',
            'Perfil',
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

    final mark = find.byKey(const ValueKey('pulso-op-mark'));
    expect(
      (tester.widget<Image>(mark).image as AssetImage).assetName,
      'assets/branding/entrenaop_op_mark.png',
    );
    expect(
      tester.getCenter(mark).dx,
      closeTo(tester.getCenter(find.byType(NavigationBar)).dx, 0.01),
    );
    await tester.tap(mark);
    await tester.pumpAndSettle();

    expect(find.text('Contenido de Entrenar'), findsOneWidget);
    expect(router.state.matchedLocation, '/plan');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/library');
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    expect(bar.selectedIndex, 1);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/profile');
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/library');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
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
    testWidgets(
      'repetir destino sube al inicio y cambiar conserva el scroll: $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = _createRouter(scrollable: true);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final home = _visibleVerticalPosition(tester);
        home.jumpTo(420);
        await tester.pumpAndSettle();
        await _tapSection(tester, 'Biblioteca');
        await tester.pumpAndSettle();
        final library = _visibleVerticalPosition(tester);
        library.jumpTo(610);
        await tester.pumpAndSettle();
        await _tapSection(tester, 'Inicio');
        await tester.pumpAndSettle();
        expect(_visibleVerticalPosition(tester).pixels, closeTo(420, .1));
        await _tapSection(tester, 'Inicio');
        await tester.pumpAndSettle();
        expect(_visibleVerticalPosition(tester).pixels, closeTo(0, .1));
        await _tapSection(tester, 'Biblioteca');
        await tester.pumpAndSettle();
        expect(_visibleVerticalPosition(tester).pixels, closeTo(610, .1));
        await _tapSection(tester, 'Biblioteca');
        await tester.pumpAndSettle();
        expect(_visibleVerticalPosition(tester).pixels, closeTo(0, .1));
        expect(tester.takeException(), isNull);
      },
    );

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
      await tester.tap(
        width < 840
            ? find.text('Entrena')
            : find.byIcon(Icons.event_note_outlined),
      );
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

  testWidgets('sube la cara visible y conserva la otra al recuperarla', (
    tester,
  ) async {
    final router = _createRouter(scrollable: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/library?tab=programs');
    await tester.pumpAndSettle();
    _visibleVerticalPosition(tester).jumpTo(450);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segunda'));
    await tester.pumpAndSettle();
    _visibleVerticalPosition(tester).jumpTo(680);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primera'));
    await tester.pumpAndSettle();
    expect(_visibleVerticalPosition(tester).pixels, closeTo(450, .1));
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(_visibleVerticalPosition(tester).pixels, closeTo(0, .1));
    expect(router.state.uri.toString(), '/library?tab=programs');
    await tester.tap(find.text('Segunda'));
    await tester.pumpAndSettle();
    expect(_visibleVerticalPosition(tester).pixels, closeTo(680, .1));
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(_visibleVerticalPosition(tester).pixels, closeTo(0, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde un detalle vuelve a portada y la lleva arriba', (
    tester,
  ) async {
    final router = _createRouter(scrollable: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    _visibleVerticalPosition(tester).jumpTo(570);
    await tester.pumpAndSettle();
    router.push('/home/detail');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
    expect(_visibleVerticalPosition(tester).pixels, closeTo(0, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('respeta la preferencia de reducir animaciones', (tester) async {
    final router = _createRouter(scrollable: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = _visibleVerticalPosition(tester);
    position.jumpTo(570);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    expect(position.pixels, closeTo(0, .1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

ScrollPosition _visibleVerticalPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .hitTestable(),
    )
    .position;

Future<void> _tapSection(WidgetTester tester, String label) async {
  final rails = find.byType(NavigationRail);
  if (rails.evaluate().isEmpty) {
    await tester.tap(find.text(label));
    return;
  }
  final rail = tester.widget<NavigationRail>(rails);
  final index = rail.destinations.indexWhere(
    (destination) => (destination.label as Text).data == label,
  );
  final destination = rail.destinations[index];
  await tester.tap(
    find.byWidget(
      index == rail.selectedIndex
          ? destination.selectedIcon
          : destination.icon,
    ),
  );
}

GoRouter _createRouter({
  bool hasTrainer = true,
  int unread = 0,
  bool scrollable = false,
}) {
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
          _branch('/home', 'Inicio', scrollable: scrollable),
          _branch('/plan', 'Entrenar'),
          _branch('/library', 'Biblioteca', scrollable: scrollable),
          StatefulShellBranch(
            initialLocation: '/profile',
            routes: [
              ..._branch('/profile', 'Perfil').routes,
              ..._branch('/assessment/history', 'Evolución').routes,
            ],
          ),
          _branch('/my-trainer', 'Preparador'),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(
  String path,
  String name, {
  bool scrollable = false,
}) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: scrollable
              ? DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Primera'),
                          Tab(text: 'Segunda'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            for (var tab = 0; tab < 2; tab++)
                              ListView.builder(
                                key: PageStorageKey('$name-$tab'),
                                itemCount: 40,
                                itemExtent: 80,
                                itemBuilder: (_, index) =>
                                    Text('$name-$tab-$index'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: Text('Contenido de $name')),
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
