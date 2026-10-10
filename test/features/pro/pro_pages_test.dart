import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/pro/domain/pro_offer.dart';
import 'package:entrenaop/features/pro/presentation/pages/pro_pages.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_discovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);

  Future<GoRouter> mount(
    WidgetTester tester, {
    String initial = '/plan',
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const offer = ProOfferContext(
      goalId: 'goal-a',
      preparationName: 'Ingreso · Tropa y marinería',
    );
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(
              child: ProDiscoveryCard(offerContext: offer),
            ),
          ),
        ),
        GoRoute(
          path: '/pro',
          builder: (_, state) =>
              ProOfferPage(offerContext: ProOfferContext.fromUri(state.uri)),
        ),
        GoRoute(
          path: '/pro/example',
          builder: (_, state) =>
              ProExamplePage(offerContext: ProOfferContext.fromUri(state.uri)),
        ),
        GoRoute(
          path: '/pro/subscription',
          builder: (_, _) => const ProSubscriptionPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el candado conserva el contexto y cerrar devuelve al origen', (
    tester,
  ) async {
    final router = await mount(tester);
    await tester.tap(find.text('Crear mi plan · Pro'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/pro');
    expect(router.state.uri.queryParameters['goal'], 'goal-a');
    expect(
      find.text('Para tu preparación: Ingreso · Tropa y marinería.'),
      findsOneWidget,
    );
    await capturePerformanceWidget(tester, 'pro-contratacion-anual');
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan');
    expect(find.text('Crear mi plan · Pro'), findsOneWidget);
  });

  testWidgets('cambiar modalidad no cobra, activa un programa ni concede Pro', (
    tester,
  ) async {
    final router = await mount(tester, initial: '/pro');
    final annual = find.text(ProBillingPeriod.annual.subscribeLabel);
    await show(tester, annual);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: annual, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    await show(tester, find.text('Mensual'));
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();
    final monthly = find.text(ProBillingPeriod.monthly.subscribeLabel);
    await show(tester, monthly);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: monthly, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('Se renueva automáticamente por 3,99 € cada mes.'),
      findsOneWidget,
    );
    expect(router.state.uri.path, '/pro');
    await show(tester, find.text('Restaurar compras'));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('Pro activado'), findsNothing);
    expect(find.text('Free'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el ejemplo didáctico abre la oferta y permite volver sin perder la preparación',
    (tester) async {
      final router = await mount(tester);
      await tester.tap(find.text('Ver un ejemplo'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/pro/example');
      expect(
        find.text('Ejemplo didáctico. No es una pauta personalizada.'),
        findsOneWidget,
      );
      await capturePerformanceWidget(tester, 'pro-ejemplo');
      await show(tester, find.text('Ver modalidades de Pro'));
      await tester.tap(find.text('Ver modalidades de Pro'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['goal'], 'goal-a');
      await show(tester, find.text('Seguir con Free'));
      await tester.tap(find.text('Seguir con Free'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/pro/example');
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/plan');
    },
  );

  testWidgets('la URL directa puede cerrar sin un origen en la pila', (
    tester,
  ) async {
    final router = await mount(tester, initial: '/pro');
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan');
  });

  testWidgets('la suscripción no inventa derechos ni deduce Free de un rol', (
    tester,
  ) async {
    await mount(tester, initial: '/pro/subscription');
    expect(find.text('Contratación próximamente disponible.'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Pro activo'), findsNothing);
    await capturePerformanceWidget(tester, 'pro-suscripcion');
  });

  for (final path in ['/pro', '/pro/example', '/pro/subscription']) {
    testWidgets('$path funciona a 320 px con texto doble', (tester) async {
      await mount(tester, initial: path, size: const Size(320, 640), scale: 2);
      final target = find.text(switch (path) {
        '/pro' => 'Restaurar compras',
        '/pro/example' => 'Ver modalidades de Pro',
        _ => 'Conocer Pro',
      });
      await show(tester, target);
      expect(tester.takeException(), isNull);
    });
  }
}
