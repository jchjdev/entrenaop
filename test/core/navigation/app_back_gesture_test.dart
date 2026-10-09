import 'package:entrenaop/core/navigation/app_back_gesture.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/core/router/material_app_route.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _mount(
  WidgetTester tester, {
  _Draft? draft,
  bool saveDraft = false,
  bool blockNative = true,
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  tester.view.physicalSize = const Size(390, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final registry = WorkflowExitRegistry();
  final router = GoRouter(
    initialLocation: '/plan',
    routes: [
      materialAppRoute(
        path: '/plan',
        builder: (_, _) => Scaffold(
          body: ListView(
            key: const PageStorageKey('consulta'),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('Fila $i')),
            ],
          ),
        ),
        routes: [
          materialAppRoute(
            path: 'detail',
            onExit: draft == null
                ? null
                : (_, state) => registry.requestExit(state.pageKey),
            builder: (_, state) {
              final page = Scaffold(
                appBar: AppBar(title: const Text('Detalle')),
                body: const TextField(),
              );
              if (draft == null) return page;
              return WorkflowExitScope(
                controller: registry.controller(state.pageKey),
                child: WorkflowDraftGuard(
                  hasUnsavedChanges: () => draft.dirty,
                  isBusy: () => draft.busy,
                  saveDraftBeforeExit: saveDraft
                      ? () async {
                          draft.saves++;
                          if (draft.fail) throw StateError('sin conexión');
                          return true;
                        }
                      : null,
                  child: PopScope(canPop: !blockNative, child: page),
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: withAppBackGesture(EntrenaTheme.dark.copyWith(platform: platform)),
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _back(WidgetTester tester) async {
  await tester.dragFrom(const Offset(2, 400), const Offset(310, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android conserva atrás del sistema y sus confirmaciones', (
    tester,
  ) async {
    final router = await _mount(
      tester,
      draft: _Draft(),
      blockNative: false,
      platform: TargetPlatform.android,
    );
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan/detail');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir sin guardar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan');
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('Gesto de la app en $platform', () => _testBackGestures(platform));
  }
}

void _testBackGestures(TargetPlatform platform) {
  testWidgets('cancelar el gesto interactivo permite volver después', (
    tester,
  ) async {
    final router = await _mount(tester, platform: platform);
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await tester.timedDragFrom(
      const Offset(2, 400),
      const Offset(35, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan/detail');
    await _back(tester);
    expect(router.state.uri.path, '/plan');
  });

  testWidgets('el gesto nativo vuelve y conserva el scroll de consulta', (
    tester,
  ) async {
    final router = await _mount(tester, platform: platform);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await _back(tester);
    expect(router.state.uri.path, '/plan');
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      before,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la raíz y un gesto interior no cambian de pantalla', (
    tester,
  ) async {
    final router = await _mount(tester, platform: platform);
    await _back(tester);
    expect(router.state.uri.path, '/plan');
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(100, 400), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan/detail');
    expect(tester.takeException(), isNull);
  });

  for (final blockNative in [false, true]) {
    testWidgets(
      'el formulario confirma y conserva texto, PopScope $blockNative',
      (tester) async {
        final router = await _mount(
          tester,
          draft: _Draft(),
          blockNative: blockNative,
          platform: platform,
        );
        router.push('/plan/detail');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'dato pendiente');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _back(tester);
        expect(find.text('¿Salir sin guardar?'), findsOneWidget);
        await tester.tap(find.text('Seguir aquí'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/plan/detail');
        expect(find.text('dato pendiente'), findsOneWidget);
        await _back(tester);
        await tester.tap(find.text('Salir sin guardar'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/plan');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('un guard ocupado bloquea también la salida por gesto', (
    tester,
  ) async {
    final draft = _Draft()..busy = true;
    final router = await _mount(tester, draft: draft, platform: platform);
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await _back(tester);
    expect(router.state.uri.path, '/plan/detail');
    expect(find.byType(AlertDialog), findsNothing);
    draft.busy = false;
    draft.dirty = false;
    await _back(tester);
    expect(router.state.uri.path, '/plan');
  });

  testWidgets('el gesto respeta el guardado de borrador y su fallo', (
    tester,
  ) async {
    final draft = _Draft()..fail = true;
    final router = await _mount(
      tester,
      draft: draft,
      saveDraft: true,
      platform: platform,
    );
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'borrador');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _back(tester);
    expect(router.state.uri.path, '/plan/detail');
    expect(find.text('borrador'), findsOneWidget);
    expect(draft.saves, 1);
    draft.fail = false;
    await _back(tester);
    expect(router.state.uri.path, '/plan');
    expect(draft.saves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestos cortos, invertidos y verticales no descartan', (
    tester,
  ) async {
    final router = await _mount(tester, draft: _Draft(), platform: platform);
    router.push('/plan/detail');
    await tester.pumpAndSettle();
    for (final offset in [
      const Offset(35, 0),
      const Offset(-200, 0),
      const Offset(0, 200),
    ]) {
      await tester.timedDragFrom(
        const Offset(2, 400),
        offset,
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/plan/detail');
      expect(find.byType(AlertDialog), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}

class _Draft {
  bool dirty = true;
  bool busy = false;
  bool fail = false;
  int saves = 0;
}
