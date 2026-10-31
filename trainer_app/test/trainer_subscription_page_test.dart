import 'package:entrenaop_trainer/trainer_subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class SubscriptionFixture implements TrainerSubscriptionRepository {
  final actions = <String>[];
  bool enabled = true;
  bool confirmed = false;
  bool pending = false;
  bool mfa = true;
  @override
  Future<bool> assured() async => mfa;
  @override
  Future<SubscriptionJson> status() async => {
    'sandbox': true,
    'enabled': enabled,
    'offers': [
      {
        'id': 'offer',
        'title': 'Ensayo de contratación',
        'amount': 100,
        'currency': 'EUR',
        'interval': 'month',
        'capacity': 5,
      },
    ],
    'subscription': confirmed || pending
        ? {
            'id': 'order',
            'state': confirmed ? 'active' : 'open',
            'paid_until': '2026-11-28T12:00:00Z',
            'cancel_at_period_end': true,
          }
        : null,
  };
  @override
  Future<SubscriptionJson> act(String action, {String? offerId}) async {
    actions.add(action);
    if (action == 'refresh') return {'state': 'open', 'confirmed': false};
    return {'url': 'https://checkout.stripe.com/c/pay/cs_test_Fixture'};
  }
}

class PlanCatalogueFixture extends SubscriptionFixture {
  String? selected;
  @override
  Future<SubscriptionJson> status() async => {
    'sandbox': true,
    'enabled': true,
    'subscription': pending
        ? {
            'id': 'order',
            'state': 'open',
            'offer_id': 'professional-10',
            'title': 'professional 10',
            'amount': 2000,
            'interval': 'month',
          }
        : null,
    'offers': [
      for (final capacity in [5, 10]) ...[
        for (final plan in ['basic', 'professional', 'complete'])
          {
            'id': '$plan-$capacity',
            'title': '$plan $capacity',
            'amount': capacity * 100 + 1000,
            'currency': 'EUR',
            'interval': 'month',
            'capacity': capacity,
            'plan_key': plan,
            'directory_option': plan != 'basic',
          },
        {
          'id': 'basic-directory-$capacity',
          'title': 'Básico con directorio $capacity',
          'amount': capacity * 100 + 1490,
          'currency': 'EUR',
          'interval': 'month',
          'capacity': capacity,
          'plan_key': 'basic',
          'directory_option': true,
        },
      ],
    ],
  };
  @override
  Future<SubscriptionJson> act(String action, {String? offerId}) async {
    selected = offerId;
    return super.act(action, offerId: offerId);
  }
}

class ConcurrentPlanFixture extends PlanCatalogueFixture {
  @override
  Future<SubscriptionJson> act(String action, {String? offerId}) async {
    pending = true;
    throw StateError('Otra pestaña ya preparó un pago');
  }
}

void main() {
  testWidgets(
    'conserva diez plazas y el complemento al volver del autenticador',
    (t) async {
      final repo = PlanCatalogueFixture()..mfa = false;
      final router = GoRouter(
        initialLocation: '/subscription',
        routes: [
          GoRoute(
            path: '/subscription',
            builder: (_, _) => TrainerSubscriptionPage(
              repository: repo,
              openPayment: (_) async => true,
            ),
          ),
          GoRoute(
            path: '/security',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  repo.mfa = true;
                  context.pop();
                },
                child: const Text('Autenticador verificado'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('Hasta 10 alumnos').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      final card = find
          .ancestor(
            of: find.text('Básico con directorio 10'),
            matching: find.byType(Column),
          )
          .first;
      final pay = find.descendant(
        of: card,
        matching: find.text('Contratar en pruebas'),
      );
      await t.ensureVisible(pay);
      await t.pumpAndSettle();
      await t.tap(pay);
      await t.pumpAndSettle();
      expect(repo.actions, isEmpty);
      expect(find.text('Autenticador verificado'), findsOneWidget);
      await t.tap(find.text('Autenticador verificado'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byType(DropdownButtonFormField<int>),
        -200,
      );
      await t.pumpAndSettle();
      expect(find.text('Hasta 10 alumnos'), findsOneWidget);
      expect(find.text('Básico con directorio 10'), findsOneWidget);
      expect(find.text('basic 5'), findsNothing);
      expect(repo.actions, isEmpty);
      await t.ensureVisible(pay);
      await t.pumpAndSettle();
      await t.tap(pay);
      await t.pumpAndSettle();
      expect(repo.selected, 'basic-directory-10');
      expect(repo.actions, ['checkout']);
    },
  );

  testWidgets(
    'recupera la oferta de otra pestaña tras un conflicto al preparar',
    (t) async {
      final repo = ConcurrentPlanFixture();
      await t.pumpWidget(
        MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Contratar en pruebas').first, 200);
      await t.tap(find.text('Contratar en pruebas').first);
      await t.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.text('basic 5'), findsNothing);
      expect(find.text('professional 10'), findsWidgets);
    },
  );

  testWidgets('un pago pendiente conserva oferta y cupo al continuar', (
    t,
  ) async {
    final repo = PlanCatalogueFixture()..pending = true;
    await t.pumpWidget(
      MaterialApp(
        home: TrainerSubscriptionPage(
          repository: repo,
          openPayment: (uri) async => true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.text('basic 5'), findsNothing);
    final button = find.text('Continuar pago de prueba');
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
    expect(repo.selected, 'professional-10');
  });
  testWidgets(
    'elige cupo y extra usando el catálogo del servidor sin precios enviados por Flutter',
    (t) async {
      final repo = PlanCatalogueFixture();
      await t.pumpWidget(
        MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
      );
      await t.pumpAndSettle();
      expect(find.text('basic 5'), findsOneWidget);
      expect(find.text('professional 10'), findsNothing);
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('Hasta 10 alumnos').last);
      await t.pumpAndSettle();
      final toggle = find.byType(SwitchListTile);
      await t.ensureVisible(toggle);
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      final name = find.text('Básico con directorio 10');
      await t.ensureVisible(name);
      await t.pumpAndSettle();
      final card = find.ancestor(of: name, matching: find.byType(Column)).first;
      final button = find.descendant(
        of: card,
        matching: find.text('Contratar en pruebas'),
      );
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(repo.selected, 'basic-directory-10');
      expect(t.takeException(), isNull);
    },
  );

  test(
    'solo acepta los destinos Stripe esperados, sin credenciales ni puertos',
    () {
      expect(
        trainerPaymentDestination(
          'https://checkout.stripe.com/c/pay/fixture',
          portal: false,
        ).host,
        'checkout.stripe.com',
      );
      for (final value in [
        'https://checkout.stripe.com.evil.invalid',
        'http://checkout.stripe.com',
        'https://user@checkout.stripe.com',
        'https://checkout.stripe.com:444',
      ]) {
        expect(
          () => trainerPaymentDestination(value, portal: false),
          throwsStateError,
        );
      }
    },
  );
  testWidgets('contratación inactiva no inicia Checkout y explica el ensayo', (
    tester,
  ) async {
    final repo = SubscriptionFixture()..enabled = false;
    await tester.pumpWidget(
      MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Contratar en pruebas'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('No es una tarifa comercial'), findsOneWidget);
    expect(repo.actions, isEmpty);
  });
  testWidgets('pago abre Checkout sin fingir que la cuenta está activada', (
    tester,
  ) async {
    final repo = SubscriptionFixture();
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerSubscriptionPage(
          repository: repo,
          openPayment: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Contratar en pruebas'));
    await tester.tap(find.text('Contratar en pruebas'));
    await tester.pumpAndSettle();
    expect(repo.actions, ['checkout']);
    expect(opened?.host, 'checkout.stripe.com');
    expect(find.text('Suscripción activa'), findsNothing);
  });
  testWidgets(
    'el retorno solicita conciliación, pero no activa un pago pendiente',
    (tester) async {
      final repo = SubscriptionFixture()..pending = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSubscriptionPage(
            repository: repo,
            returnedFromCheckout: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.actions, ['refresh']);
      expect(find.text('Suscripción activa'), findsNothing);
      expect(find.text('Contratación pendiente'), findsOneWidget);
      expect(find.textContaining('Estado actualizado.'), findsOneWidget);
    },
  );
  testWidgets(
    'una URL de retorno sin pedido no inicia compra ni concede acceso',
    (tester) async {
      final repo = SubscriptionFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSubscriptionPage(
            repository: repo,
            returnedFromCheckout: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.actions, isEmpty);
      expect(find.text('Suscripción activa'), findsNothing);
    },
  );
}
