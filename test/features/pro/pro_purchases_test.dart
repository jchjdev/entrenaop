import 'dart:async';

import 'package:entrenaop/features/pro/data/revenuecat_pro_purchase_repository.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/pro/domain/pro_offer.dart';
import 'package:entrenaop/features/pro/domain/pro_purchases.dart';
import 'package:entrenaop/features/pro/presentation/bloc/pro_purchase_cubit.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_purchase_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/router/material_app_route.dart';
import 'package:entrenaop/features/pro/presentation/pages/pro_pages.dart';
import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../support/account_auth_fixture.dart';

const configuration = ProPurchaseConfiguration(
  key: 'test_fixture',
  development: true,
  debug: true,
  mobile: true,
);
ProAccess access({bool pro = true, String user = 'a'}) => ProAccess(
  userId: user,
  isPro: pro,
  checkedAt: DateTime.utc(2026, 10, 13),
  validUntil: pro ? DateTime.utc(2026, 11, 13) : null,
  personalExercises: 0,
  personalSessions: 0,
  source: pro ? 'revenuecat' : null,
  billingEnvironment: pro ? 'SANDBOX' : null,
);
final catalogProducts = [
  for (final period in ProBillingPeriod.values)
    ProStoreProduct(
      period: period,
      identifier: period.name,
      price: period == ProBillingPeriod.annual ? 29.99 : 3.99,
      priceLabel: period == ProBillingPeriod.annual
          ? '29,99 US\$'
          : '3,99 US\$',
      currencyCode: 'USD',
    ),
];

class Store extends ProStoreGateway {
  int purchases = 0, restorations = 0;
  final identities = <String>[];
  Completer<void>? pending;
  Completer<bool>? activeCheck;
  PlatformException? error;
  bool active = false;
  @override
  Future<void> identify(String userId) async {
    identities.add(userId);
  }

  @override
  Future<List<ProStoreProduct>> products() async => catalogProducts;
  @override
  Future<bool> hasActivePro() async =>
      activeCheck == null ? active : await activeCheck!.future;
  @override
  Future<void> purchase(ProBillingPeriod period) async {
    purchases++;
    if (error != null) throw error!;
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> restore() async {
    restorations++;
  }
}

void main() {
  testWidgets(
    'una confirmación sin respuesta termina pendiente con un único intento de compra',
    (tester) async {
      final store = Store();
      final unanswered = Completer<ProAccess>();
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => 'a',
        confirm: (_) => unanswered.future,
        waitBeforeConfirmationRetry: () async {},
      );
      final cubit = ProPurchaseCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final operation = cubit.buy(ProBillingPeriod.annual);
      await tester.pump();
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.pump(const Duration(seconds: 12));
      }
      await operation;
      expect(cubit.state.phase, ProPurchasePhase.pending);
      expect(store.purchases, 1);
    },
  );
  test(
    'una anual con confirmación tardía activa Pro sin restaurar ni recomprar',
    () async {
      final store = Store();
      var confirmations = 0;
      var waits = 0;
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => 'a',
        confirm: (_) async => access(pro: ++confirmations >= 2),
        waitBeforeConfirmationRetry: () async {
          waits++;
        },
      );
      expect((await repository.purchase(ProBillingPeriod.annual)).isPro, true);
      expect(confirmations, 2);
      expect(waits, 1);
      expect(store.purchases, 1);
      expect(store.restorations, 0);
    },
  );
  test('un fallo transitorio después de comprar se vuelve a comprobar sin pagar otra vez', () async {
    final store = Store();
    var confirmations = 0;
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: store,
      owner: () => 'a',
      confirm: (_) async {
        if (++confirmations == 1) {
          throw StateError('Confirmación temporalmente no disponible');
        }
        return access();
      },
      waitBeforeConfirmationRetry: () async {},
    );
    expect((await repository.purchase(ProBillingPeriod.monthly)).isPro, true);
    expect(store.purchases, 1);
    expect(confirmations, 2);
  });
  test('cambiar de cuenta durante la espera corta los reintentos', () async {
    var owner = 'a';
    var confirmations = 0;
    final wait = Completer<void>();
    final waiting = Completer<void>();
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: Store(),
      owner: () => owner,
      confirm: (_) async {
        confirmations++;
        return access(pro: false);
      },
      waitBeforeConfirmationRetry: () {
        waiting.complete();
        return wait.future;
      },
    );
    final operation = repository.purchase(ProBillingPeriod.annual);
    final rejected = expectLater(
      operation,
      throwsA(isA<ProPurchaseException>()),
    );
    await waiting.future;
    owner = 'b';
    wait.complete();
    await rejected;
    expect(confirmations, 1);
  });
  testWidgets(
    'confirmación retrasada cambia la oferta a Ya tienes Pro automáticamente',
    (tester) async {
      final store = Store();
      var confirmed = false;
      var confirmations = 0;
      final wait = Completer<void>();
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => 'a',
        confirm: (_) async {
          confirmed = ++confirmations >= 2;
          return access(pro: confirmed);
        },
        waitBeforeConfirmationRetry: () => wait.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProOfferPage(
            purchases: repository,
            loadAccess: () async => access(pro: confirmed),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buy = find.text('Probar por 29,99 US\$/año');
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Comprobando el acceso con el servidor…'),
        findsOneWidget,
      );
      expect(find.text('Ya tienes Pro'), findsNothing);
      wait.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ya tienes Pro'), findsOneWidget);
      expect(find.text('Seguir con Free'), findsNothing);
      expect(store.purchases, 1);
      expect(store.restorations, 0);
    },
  );
  for (final path in ['/pro', '/pro/subscription']) {
    testWidgets(
      'volver a Mi plan desde $path no duplica la navegación principal',
      (tester) async {
        final repository = _Repository();
        final rootKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: rootKey,
          initialLocation: '/profile',
          routes: [
            StatefulShellRoute.indexedStack(
              pageBuilder: (_, state, shell) =>
                  MaterialPage<Object?>(key: state.pageKey, child: shell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    materialAppRoute(
                      path: '/plan',
                      builder: (_, _) =>
                          const Scaffold(body: Text('Mi plan abierto')),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    materialAppRoute(
                      path: '/profile',
                      builder: (_, _) =>
                          const Scaffold(body: Text('Perfil abierto')),
                    ),
                  ],
                ),
              ],
            ),
            materialAppRoute(
              path: '/pro',
              builder: (_, _) => ProOfferPage(
                purchases: repository,
                loadAccess: () async => access(pro: repository.buys > 0),
              ),
            ),
            materialAppRoute(
              path: '/pro/subscription',
              builder: (_, _) =>
                  ProSubscriptionPage(loadAccess: () async => access()),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        router.push<void>(path);
        await tester.pumpAndSettle();
        if (path == '/pro') {
          final buy = find.text('Probar por 29,99 US\$/año');
          await tester.ensureVisible(buy);
          await tester.tap(buy);
          await tester.pumpAndSettle();
          expect(find.text('Ya tienes Pro'), findsOneWidget);
          expect(find.text('Seguir con Free'), findsNothing);
          expect(find.text('Probar por 29,99 US\$/año'), findsNothing);
        }
        final returnToPlan = find.text('Ir a Mi plan');
        await tester.ensureVisible(returnToPlan);
        await tester.tap(returnToPlan);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(router.state.uri.path, '/plan');
        expect(find.text('Mi plan abierto'), findsOneWidget);
      },
    );
  }
  for (final path in ['/pro', '/pro/subscription']) {
    testWidgets('cambiar cuenta en $path descarta el estado Pro anterior', (
      tester,
    ) async {
      final fixture = AccountAuthFixture();
      final auth = fixture.cubit()..watchAuthState();
      await auth.checkCurrentUser();
      sl.registerSingleton<ProAccessRepository>(
        _AccountAccess(owner: () => (auth.state as AuthAuthenticated).user.id),
      );
      addTearDown(sl.reset);
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      addTearDown(auth.close);
      addTearDown(fixture.changes.close);
      router.config.go(path);
      await tester.pumpWidget(
        BlocProvider.value(
          value: auth,
          child: MaterialApp.router(routerConfig: router.config),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro activo'), findsOneWidget);
      fixture.changes.add(
        AuthSessionChange(
          UserEntity(
            id: 'b',
            email: 'otra@example.invalid',
            role: 'user',
            createdAt: DateTime.utc(2026, 10, 13),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro activo'), findsNothing);
      expect(
        find.text(path == '/pro' ? 'Seguir con Free' : 'Cuenta Free'),
        findsOneWidget,
      );
    });
  }
  test('la clave de Test Store requiere desarrollo móvil debug', () {
    expect(configuration.enabled, true);
    for (final value in [
      const ProPurchaseConfiguration(
        key: '',
        development: true,
        debug: true,
        mobile: true,
      ),
      const ProPurchaseConfiguration(
        key: 'test_fixture',
        development: false,
        debug: true,
        mobile: true,
      ),
      const ProPurchaseConfiguration(
        key: 'test_fixture',
        development: true,
        debug: false,
        mobile: true,
      ),
      const ProPurchaseConfiguration(
        key: 'test_fixture',
        development: true,
        debug: true,
        mobile: false,
      ),
      const ProPurchaseConfiguration(
        key: 'appl_fixture',
        development: true,
        debug: true,
        mobile: true,
      ),
    ]) {
      expect(value.enabled, false);
    }
  });
  test(
    'el resultado de tienda no concede Pro si el servidor devuelve Free',
    () async {
      final store = Store();
      var confirmations = 0;
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => 'a',
        confirm: (_) async {
          confirmations++;
          return access(pro: false);
        },
        waitBeforeConfirmationRetry: () async {},
      );
      final result = await repository.purchase(ProBillingPeriod.monthly);
      expect(store.purchases, 1);
      expect(result.isPro, false);
      expect(confirmations, 3);
    },
  );
  test(
    'cambiar cuenta durante la compra no verifica con la cuenta nueva',
    () async {
      final store = Store()..pending = Completer<void>();
      var owner = 'a';
      var confirmations = 0;
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => owner,
        confirm: (_) async {
          confirmations++;
          return access();
        },
      );
      final operation = repository.purchase(ProBillingPeriod.monthly);
      final rejected = expectLater(
        operation,
        throwsA(isA<ProPurchaseException>()),
      );
      await Future<void>.delayed(Duration.zero);
      owner = 'b';
      store.pending!.complete();
      await rejected;
      expect(confirmations, 0);
    },
  );
  test('un recibo ya activo se concilia sin volver a comprar', () async {
    final store = Store()..active = true;
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: store,
      owner: () => 'a',
      confirm: (_) async => access(),
    );
    expect((await repository.purchase(ProBillingPeriod.annual)).isPro, true);
    expect(store.purchases, 0);
  });
  test(
    'cambiar cuenta antes del diálogo impide iniciar la compra anterior',
    () async {
      final store = Store()..activeCheck = Completer<bool>();
      var owner = 'a';
      final repository = RevenueCatProPurchaseRepository(
        configuration: configuration,
        store: store,
        owner: () => owner,
        confirm: (_) async => access(),
      );
      final operation = repository.purchase(ProBillingPeriod.annual);
      final rejected = expectLater(
        operation,
        throwsA(isA<ProPurchaseException>()),
      );
      await Future<void>.delayed(Duration.zero);
      owner = 'b';
      store.activeCheck!.complete(false);
      await rejected;
      expect(store.purchases, 0);
    },
  );
  test('restaurar sin compras vigentes permite suscribirse después', () async {
    final repository = _Repository()..result = access(pro: false);
    final cubit = ProPurchaseCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.restore();
    expect(cubit.state.phase, ProPurchasePhase.ready);
    await cubit.buy(ProBillingPeriod.monthly);
    expect(repository.buys, 1);
    expect(cubit.state.phase, ProPurchasePhase.pending);
  });
  test('cancelar el diálogo no confirma ni activa el acceso', () async {
    final store = Store()..error = PlatformException(code: '1');
    var confirmations = 0;
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: store,
      owner: () => 'a',
      confirm: (_) async {
        confirmations++;
        return access();
      },
    );
    await expectLater(
      repository.purchase(ProBillingPeriod.monthly),
      throwsA(
        isA<ProPurchaseException>().having(
          (e) => e.cancelled,
          'cancelled',
          true,
        ),
      ),
    );
    expect(confirmations, 0);
  });
  test('una respuesta de servidor de otra identidad se rechaza', () async {
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: Store(),
      owner: () => 'a',
      confirm: (_) async => access(user: 'b'),
    );
    await expectLater(
      repository.restore(),
      throwsA(isA<ProPurchaseException>()),
    );
  });
  test(
    'evita operaciones simultáneas y repetir compra pendiente de verificación',
    () async {
      final repository = _Repository()..pending = Completer<ProAccess>();
      final cubit = ProPurchaseCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final operation = cubit.buy(ProBillingPeriod.monthly);
      await cubit.buy(ProBillingPeriod.annual);
      expect(repository.buys, 1);
      repository.pending!.complete(access(pro: false));
      await operation;
      expect(cubit.state.phase, ProPurchasePhase.pending);
      await cubit.buy(ProBillingPeriod.annual);
      expect(repository.buys, 1);
      repository.pending = null;
      await cubit.synchronize();
      expect(cubit.state.phase, ProPurchasePhase.active);
    },
  );
  test('un fallo de confirmación después de comprar pide comprobar, no repetir compra', () async {
    final repository = RevenueCatProPurchaseRepository(
      configuration: configuration,
      store: Store(),
      owner: () => 'a',
      confirm: (_) async => throw StateError('Sin conexión'),
      waitBeforeConfirmationRetry: () async {},
    );
    final cubit = ProPurchaseCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.buy(ProBillingPeriod.annual);
    expect(cubit.state.phase, ProPurchasePhase.pending);
  });
  testWidgets(
    'precio y moneda proceden del catálogo y solo confirma tras servidor',
    (tester) async {
      final repository = _Repository();
      var verified = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProPurchasePanel(
              repository: repository,
              onVerified: () {
                verified++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Probar por 29,99 US\$/año'), findsOneWidget);
      expect(find.textContaining('29,99 €'), findsNothing);
      await tester.tap(find.text('Probar por 29,99 US\$/año'));
      await tester.pumpAndSettle();
      expect(verified, 1);
    },
  );
  testWidgets(
    'la confirmación pendiente mantiene compra deshabilitada y permite consultar',
    (tester) async {
      final repository = _Repository()..result = access(pro: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProPurchasePanel(repository: repository, onVerified: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Probar por 29,99 US\$/año'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobar acceso'), findsOneWidget);
      final buy = find.widgetWithText(
        FilledButton,
        'Probar por 29,99 US\$/año',
      );
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
      repository.result = access();
      await tester.tap(find.text('Comprobar acceso'));
      await tester.pumpAndSettle();
      expect(repository.buys, 1);
    },
  );
}

class _Repository implements ProPurchaseRepository {
  Completer<ProAccess>? pending;
  ProAccess result = access();
  int buys = 0;
  @override
  bool get enabled => true;
  @override
  String get unavailableMessage => 'No disponible';
  @override
  Future<List<ProStoreProduct>> products() async => catalogProducts;
  @override
  Future<ProAccess> purchase(ProBillingPeriod period) async {
    buys++;
    return pending == null ? result : pending!.future;
  }

  @override
  Future<ProAccess> restore() async => result;
  @override
  Future<ProAccess> synchronize() async => result;
}

class _AccountAccess implements ProAccessRepository {
  _AccountAccess({required this.owner});
  final String Function() owner;
  @override
  Future<ProAccess> load() async => access(pro: owner() != 'b', user: owner());
}
