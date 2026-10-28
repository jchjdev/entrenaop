import 'package:entrenaop_trainer/trainer_subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
