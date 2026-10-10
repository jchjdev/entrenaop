import 'dart:async';

import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/pro/domain/pro_offer.dart';
import 'package:entrenaop/features/pro/presentation/pages/pro_pages.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_discovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pro_access_fixture.dart';
import '../../helpers/performance_visual_review.dart';

import 'package:entrenaop/core/theme/entrena_theme.dart';

void main() {
  setUpAll(loadReviewFont);
  Map<String, dynamic> snapshot({String tier = 'free'}) => {
    'user_id': 'fixture',
    'tier': tier,
    'checked_at': '2026-10-10T12:00:00Z',
    'valid_until': tier == 'pro' ? '2026-11-10T12:00:00Z' : null,
    'source': tier == 'pro' ? 'development_manual' : null,
    'personal_exercises': 9,
    'personal_sessions': 5,
  };
  test('Free conserva recuentos superiores a su cuota después de caducar', () {
    final access = ProAccess.fromJson(snapshot());
    expect(access.isPro, false);
    expect(access.personalExercises, 9);
    expect(access.personalSessions, 5);
    expect(access.exerciseLimit, 8);
    expect(access.sessionLimit, 4);
  });
  test('Pro requiere vigencia comprobada y no tiene las cuotas Free', () {
    final access = ProAccess.fromJson(snapshot(tier: 'pro'));
    expect(access.isPro, true);
    expect(access.exerciseLimit, isNull);
    expect(access.sessionLimit, isNull);
    expect(
      () => ProAccess.fromJson({
        ...snapshot(tier: 'pro'),
        'valid_until': '2026-10-09T12:00:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => ProAccess.fromJson({...snapshot(tier: 'pro'), 'valid_until': null}),
      throwsFormatException,
    );
    expect(
      () => ProAccess.fromJson(snapshot(tier: 'admin')),
      throwsFormatException,
    );
  });
  test('solo códigos comerciales conocidos abren la oferta', () {
    expect(
      ProAccessDenied.fromDetails('free_exercise_limit')?.restriction,
      ProRestriction.exercises,
    );
    expect(
      ProAccessDenied.fromDetails('free_session_limit')?.restriction,
      ProRestriction.sessions,
    );
    expect(
      ProAccessDenied.fromDetails('pro_required')?.restriction,
      ProRestriction.adaptiveProgram,
    );
    expect(ProAccessDenied.fromDetails('42501'), isNull);
  });
  Future<void> mount(WidgetTester tester, Widget child) async {
    if (capturePerformanceReview) {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: EntrenaTheme.dark,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  for (final pro in [false, true]) {
    testWidgets('el acceso $pro protege incluso la URL directa del programa', (
      tester,
    ) async {
      final repository = ProAccessFixture(isPro: pro);
      await mount(
        tester,
        ProAccessGate(
          load: repository.load,
          child: const Text('Configuración real'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Configuración real'),
        pro ? findsOneWidget : findsNothing,
      );
      expect(find.byType(ProOfferPage), pro ? findsNothing : findsOneWidget);
    });
    testWidgets('Mi suscripción muestra el estado $pro del servidor', (
      tester,
    ) async {
      final repository = ProAccessFixture(isPro: pro);
      await mount(tester, ProSubscriptionPage(loadAccess: repository.load));
      await tester.pumpAndSettle();
      expect(find.text(pro ? 'Pro activo' : 'Cuenta Free'), findsOneWidget);
      if (pro) {
        expect(
          find.textContaining('No es una suscripción de pago'),
          findsOneWidget,
        );
      }
      await capturePerformanceWidget(
        tester,
        pro ? 'pro-acceso-activo' : 'pro-acceso-free',
      );
    });
  }
  testWidgets('carga y error de verificación no se interpretan como Free', (
    tester,
  ) async {
    final pending = Completer<ProAccess>();
    var attempt = 0;
    Future<ProAccess> load() =>
        attempt++ == 0 ? pending.future : ProAccessFixture(isPro: true).load();
    await mount(
      tester,
      ProAccessGate(load: load, child: const Text('Configuración real')),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ProOfferPage), findsNothing);
    pending.completeError(StateError('Sin conexión'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(ProOfferPage), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Configuración real'), findsOneWidget);
  });
  testWidgets(
    'el acceso Pro contextual abre configuración sin volver a pagar',
    (tester) async {
      final repository = ProAccessFixture(isPro: true);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ProDiscoveryCard(
                loadAccess: repository.load,
                offerContext: const ProOfferContext(goalId: 'goal'),
              ),
            ),
          ),
          GoRoute(
            path: '/plan/goal/goal/training',
            builder: (_, _) => const Scaffold(body: Text('Programa')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configurar mi plan'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/plan/goal/goal/training');
    },
  );
}
