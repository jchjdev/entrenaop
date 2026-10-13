import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/pro_access.dart';
import '../domain/pro_offer.dart';
import '../domain/pro_purchases.dart';

/// Frontera pequeña para probar los cambios de identidad y los errores del SDK.
abstract class ProStoreGateway {
  Future<void> identify(String userId);
  Future<List<ProStoreProduct>> products();
  Future<bool> hasActivePro();
  Future<void> purchase(ProBillingPeriod period);
  Future<void> restore();
}

class RevenueCatStoreGateway implements ProStoreGateway {
  RevenueCatStoreGateway(this.key);
  final String key;
  bool _configured = false;
  final _packages = <ProBillingPeriod, Package>{};

  @override
  Future<void> identify(String userId) async {
    if (!_configured) {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(
        PurchasesConfiguration(key)..appUserID = userId,
      );
      _configured = true;
    } else if (await Purchases.appUserID != userId) {
      await Purchases.logIn(userId);
      _packages.clear();
    }
  }

  @override
  Future<List<ProStoreProduct>> products() async {
    final offering = (await Purchases.getOfferings()).all['default'];
    if (offering == null) {
      throw const ProPurchaseException(
        'No se han podido cargar las modalidades de Pro.',
      );
    }
    final result = <ProStoreProduct>[];
    _packages.clear();
    for (final period in ProBillingPeriod.values) {
      final package = period == ProBillingPeriod.annual
          ? offering.annual
          : offering.monthly;
      final expected = period == ProBillingPeriod.annual
          ? 'entrenaop_pro_annual'
          : 'entrenaop_pro_monthly';
      if (package == null ||
          package.storeProduct.identifier != expected ||
          package.storeProduct.price <= 0) {
        throw const ProPurchaseException(
          'Las modalidades de Pro todavía no están disponibles.',
        );
      }
      _packages[period] = package;
      final product = package.storeProduct;
      result.add(
        ProStoreProduct(
          period: period,
          identifier: product.identifier,
          price: product.price,
          priceLabel: product.priceString,
          currencyCode: product.currencyCode,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> purchase(ProBillingPeriod period) async {
    if (!_packages.containsKey(period)) await products();
    await Purchases.purchase(PurchaseParams.package(_packages[period]!));
  }

  @override
  Future<bool> hasActivePro() async => (await Purchases.getCustomerInfo())
      .entitlements
      .active
      .containsKey('pro');
  @override
  Future<void> restore() async {
    await Purchases.restorePurchases();
  }
}

class RevenueCatProPurchaseRepository implements ProPurchaseRepository {
  RevenueCatProPurchaseRepository({
    required this.configuration,
    required this.store,
    required this.owner,
    required this.confirm,
  });
  final ProPurchaseConfiguration configuration;
  final ProStoreGateway store;
  final String? Function() owner;
  final Future<ProAccess> Function(String userId) confirm;
  Future<void> _queue = Future.value();
  @override
  bool get enabled => configuration.enabled;
  @override
  String get unavailableMessage => configuration.unavailableMessage;

  Future<T> _run<T>(Future<T> Function(String userId) action) {
    final current = owner();
    if (!enabled) return Future.error(ProPurchaseException(unavailableMessage));
    if (current == null) {
      return Future.error(
        const ProPurchaseException('Inicia sesión para continuar.'),
      );
    }
    // El SDK comparte identidad global: no se solapan logIn/compra/restauración.
    final result = _queue.then((_) async {
      _checkOwner(current);
      try {
        await store.identify(current);
        _checkOwner(current);
        final value = await action(current);
        _checkOwner(current);
        return value;
      } on PlatformException catch (error) {
        final code = int.tryParse(error.code);
        if (code == PurchasesErrorCode.purchaseCancelledError.index) {
          throw const ProPurchaseException(
            'Has cancelado la compra.',
            cancelled: true,
          );
        }
        if (code == PurchasesErrorCode.paymentPendingError.index) {
          throw const ProPurchaseException(
            'La compra está pendiente. Comprobaremos el acceso cuando se confirme.',
            pending: true,
          );
        }
        throw const ProPurchaseException(
          'No se ha podido completar la operación. Vuelve a intentarlo.',
        );
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkOwner(String userId) {
    if (owner() != userId) {
      throw const ProPurchaseException(
        'La cuenta ha cambiado. Vuelve a abrir Mi suscripción.',
      );
    }
  }

  Future<ProAccess> _confirm(String userId) async {
    _checkOwner(userId);
    try {
      final access = await confirm(userId);
      _checkOwner(userId);
      if (access.userId != userId) {
        throw const ProPurchaseException('La cuenta ha cambiado.');
      }
      return access;
    } on ProPurchaseException {
      rethrow;
    } catch (_) {
      throw const ProPurchaseException(
        'La operación se ha registrado. Falta confirmar el acceso; no repitas la compra.',
        pending: true,
      );
    }
  }

  @override
  Future<List<ProStoreProduct>> products() => _run((_) => store.products());
  @override
  Future<ProAccess> purchase(ProBillingPeriod period) => _run((userId) async {
    // Un recibo ya activo debe conciliarse, no comprarse de nuevo.
    final active = await store.hasActivePro();
    _checkOwner(userId);
    if (active) return _confirm(userId);
    await store.purchase(period);
    return _confirm(userId);
  });
  @override
  Future<ProAccess> restore() => _run((userId) async {
    await store.restore();
    return _confirm(userId);
  });
  @override
  Future<ProAccess> synchronize() => _run(_confirm);

  static Future<ProAccess> confirmWithSupabase(
    SupabaseClient client,
    String userId,
  ) async {
    final response = await client.functions.invoke(
      'revenuecat-sync',
      body: {'expected_user_id': userId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return ProAccess.fromJson(Map<String, dynamic>.from(data['access'] as Map));
  }
}
