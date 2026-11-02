import 'package:entrenaop_trainer/trainer_subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class SubscriptionFixture implements TrainerSubscriptionRepository {
  bool suspended = false;
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
    'suspended': suspended,
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
  Future<SubscriptionJson> act(
    String action, {
    String? offerId,
    String? changeId,
  }) async {
    actions.add(action);
    if (action == 'refresh') return {'state': 'open', 'confirmed': false};
    return {'url': 'https://checkout.stripe.com/c/pay/cs_test_Fixture'};
  }
}

class PlanCatalogueFixture extends SubscriptionFixture {
  String? selected;
  List<int> capacities = const [5, 10];
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
            'capacity': 10,
            'currency': 'EUR',
            'interval': 'month',
          }
        : null,
    'offers': [
      for (final capacity in capacities) ...[
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
  Future<SubscriptionJson> act(
    String action, {
    String? offerId,
    String? changeId,
  }) async {
    selected = offerId;
    return super.act(action, offerId: offerId, changeId: changeId);
  }
}

class ConcurrentPlanFixture extends PlanCatalogueFixture {
  @override
  Future<SubscriptionJson> act(
    String action, {
    String? offerId,
    String? changeId,
  }) async {
    pending = true;
    throw StateError('Otra pestaña ya preparó un pago');
  }
}

class RetiredPendingFixture extends PlanCatalogueFixture {
  RetiredPendingFixture() {
    pending = true;
  }
  @override
  Future<SubscriptionJson> status() async {
    final data = await super.status();
    data['offers'] = (data['offers'] as List)
        .where((o) => o['id'] != 'professional-10')
        .toList();
    return data;
  }
}

class PlanChangeFixture extends PlanCatalogueFixture {
  final operations = <String>[];
  Map<String, dynamic>? change;
  String kind = 'immediate';
  @override
  Future<SubscriptionJson> status() async => {
    ...await super.status(),
    'suspended': suspended,
    'subscription': {
      'id': 'order',
      'state': 'active',
      'offer_id': 'basic-5',
      'title': 'Básico actual',
      'amount': 1500,
      'interval': 'month',
      'paid_until': '2099-11-30T12:00:00Z',
    },
    'change': change,
  };
  @override
  Future<SubscriptionJson> act(
    String action, {
    String? offerId,
    String? changeId,
  }) async {
    operations.add(action);
    if (action == 'quote_change') {
      selected = offerId;
      final offers = (await super.status())['offers'] as List;
      change = {
        'id': 'change-one',
        'state': 'quoted',
        'kind': kind,
        'amount': kind == 'renewal' ? 0 : 620,
        'effective_at': '2099-11-30T12:00:00Z',
        'offer': offers.firstWhere((o) => o['id'] == offerId),
      };
      return {'change': change};
    }
    if (action == 'confirm_change') {
      expect(changeId, 'change-one');
      change!['state'] = kind == 'renewal' ? 'scheduled' : 'applied';
      return {
        'state': kind == 'renewal' ? 'scheduled' : 'active',
        'confirmed': kind != 'renewal',
      };
    }
    if (action == 'cancel_change') {
      change!['state'] = 'canceled';
      return {'state': 'canceled_change'};
    }
    return {'confirmed': false};
  }
}

void main() {
  testWidgets(
    'la suspensión permite anular un cambio pero no confirmar nuevos cargos',
    (tester) async {
      final repo = PlanChangeFixture()..suspended = true;
      repo.change = {
        'id': 'change-one',
        'state': 'quoted',
        'kind': 'renewal',
        'amount': 0,
        'effective_at': '2099-11-30T12:00:00Z',
        'offer': {'title': 'Básico reducido', 'capacity': 5, 'amount': 1500},
      };
      await tester.pumpWidget(
        MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(
        FilledButton,
        'Confirmar cambio en pruebas',
      );
      await tester.scrollUntilVisible(confirm, 250);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      final cancel = find.text('Anular cambio');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(repo.operations, ['cancel_change']);
    },
  );
  Future<void> chooseChange(WidgetTester tester, PlanChangeFixture repo) async {
    await tester.pumpWidget(
      MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('trainer-capacity')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trainer-capacity')),
      '10',
    );
    await tester.pumpAndSettle();
    final card = find
        .ancestor(of: find.text('basic 10'), matching: find.byType(Column))
        .first;
    final review = find.descendant(
      of: card,
      matching: find.text('Revisar cambio'),
    );
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'revisar ampliación muestra diferencia sin cobrar hasta confirmar',
    (tester) async {
      final repo = PlanChangeFixture();
      await chooseChange(tester, repo);
      expect(repo.operations, ['quote_change']);
      expect(find.text('Importe ahora: 6.20 € (pruebas)'), findsOneWidget);
      expect(find.textContaining('cuando Stripe confirme'), findsOneWidget);
      final confirm = find.text('Confirmar cambio en pruebas');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repo.operations, ['quote_change', 'confirm_change']);
      expect(repo.selected, 'basic-10');
    },
  );
  testWidgets(
    'reducción muestra fecha y coste cero y permite anular el cambio programado',
    (tester) async {
      final repo = PlanChangeFixture()..kind = 'renewal';
      await chooseChange(tester, repo);
      expect(find.text('Importe ahora: 0.00 € (pruebas)'), findsOneWidget);
      expect(find.textContaining('Se aplicará al renovar:'), findsOneWidget);
      final confirm = find.text('Confirmar cambio en pruebas');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Cambio programado'), findsOneWidget);
      final cancel = find.text('Anular cambio');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(repo.operations, [
        'quote_change',
        'confirm_change',
        'cancel_change',
      ]);
      expect(find.text('Cambio programado'), findsNothing);
    },
  );
  test(
    'la factura pendiente solo puede abrirse en el destino de Stripe esperado',
    () {
      expect(
        trainerChangePaymentDestination('https://invoice.stripe.com/i/test_own')
            .host,
        'invoice.stripe.com',
      );
      for (final value in [
        'https://evil.invalid/',
        'http://invoice.stripe.com/i/a',
        'https://x@invoice.stripe.com/i/a',
        'https://invoice.stripe.com:444/i/a',
      ]) {
        expect(() => trainerChangePaymentDestination(value), throwsStateError);
      }
    },
  );
  testWidgets('no ofrece pagar al suspendido sin suscripción activa', (
    tester,
  ) async {
    final repo = SubscriptionFixture()..suspended = true;
    await tester.pumpWidget(
      MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Acceso profesional suspendido'),
      findsOneWidget,
    );
    expect(find.text('Contratar en pruebas'), findsNothing);
    expect(find.text('Continuar pago de prueba'), findsNothing);
    expect(repo.actions, isEmpty);
  });

  testWidgets(
    'la suspensión conserva gestión de cobros y oculta nuevas compras',
    (tester) async {
      final repo = SubscriptionFixture()
        ..confirmed = true
        ..suspended = true;
      await tester.pumpWidget(
        MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Acceso profesional suspendido'),
        findsOneWidget,
      );
      expect(find.text('Gestionar suscripción'), findsOneWidget);
      expect(find.text('Entrar al panel'), findsNothing);
      expect(find.byKey(const ValueKey('trainer-capacity')), findsNothing);
      expect(repo.actions, isEmpty);
    },
  );

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
      await t.enterText(find.byKey(const ValueKey('trainer-capacity')), '10');
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
        find.byKey(const ValueKey('trainer-capacity')),
        -200,
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const ValueKey('trainer-capacity')),
            )
            .controller!
            .text,
        '10',
      );
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
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('trainer-offer-basic-5')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('trainer-offer-basic-5')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('trainer-capacity')), findsNothing);
      expect(find.text('basic 5'), findsNothing);
      expect(find.text('professional 10'), findsWidgets);
    },
  );

  testWidgets(
    'un pedido propio retoma su oferta retirada sin comprar el catálogo nuevo',
    (t) async {
      final repo = RetiredPendingFixture();
      await t.pumpWidget(
        MaterialApp(
          home: TrainerSubscriptionPage(
            repository: repo,
            openPayment: (_) async => true,
          ),
        ),
      );
      await t.pumpAndSettle();
      final pay = find.byKey(const ValueKey('trainer-offer-professional-10'));
      await t.scrollUntilVisible(
        pay,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(pay);
      await t.pumpAndSettle();
      expect(repo.selected, 'professional-10');
      expect(repo.actions, ['checkout']);
      expect(find.byKey(const ValueKey('trainer-capacity')), findsNothing);
      expect(t.takeException(), isNull);
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
    expect(find.byKey(const ValueKey('trainer-capacity')), findsNothing);
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
      await t.scrollUntilVisible(
        find.text('basic 5'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('basic 5'), findsOneWidget);
      expect(find.text('professional 10'), findsNothing);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('trainer-capacity')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(find.byKey(const ValueKey('trainer-capacity')), '10');
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

  testWidgets(
    'cupo por unidades y entrada inválida nunca contrata la selección anterior',
    (t) async {
      final repo = PlanCatalogueFixture()
        ..capacities = List.generate(96, (i) => i + 5);
      await t.pumpWidget(
        MaterialApp(
          home: TrainerSubscriptionPage(
            repository: repo,
            openPayment: (_) async => true,
          ),
        ),
      );
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('trainer-capacity'));
      await t.enterText(field, '4');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('trainer-offer-basic-5')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const ValueKey('trainer-offer-basic-5')),
            )
            .onPressed,
        isNull,
      );
      expect(repo.actions, isEmpty);
      await t.scrollUntilVisible(
        field,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(field, '7');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Ampliar cupo'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(field).controller!.text, '8');
      await t.tap(find.byTooltip('Reducir cupo'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(field).controller!.text, '7');
      final buy = find.byKey(const ValueKey('trainer-offer-basic-7'));
      await t.scrollUntilVisible(
        buy,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(buy);
      await t.pumpAndSettle();
      expect(repo.selected, 'basic-7');
      expect(repo.actions, ['checkout']);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'un atajo corrige el texto inválido y respeta los límites del cupo',
    (t) async {
      final repo = PlanCatalogueFixture()
        ..capacities = List.generate(96, (i) => i + 5);
      await t.pumpWidget(
        MaterialApp(home: TrainerSubscriptionPage(repository: repo)),
      );
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('trainer-capacity'));
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(field, '101');
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ActionChip, '100'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(field).controller!.text, '100');
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_circle_outline),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Elige un cupo disponible.'), findsNothing);
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
