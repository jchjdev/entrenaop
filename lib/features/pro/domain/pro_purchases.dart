import 'pro_access.dart';
import 'pro_offer.dart';

class ProStoreProduct {
  const ProStoreProduct({
    required this.period,
    required this.identifier,
    required this.price,
    required this.priceLabel,
    required this.currencyCode,
  });
  final ProBillingPeriod period;
  final String identifier, priceLabel, currencyCode;
  final double price;
}

class ProPurchaseException implements Exception {
  const ProPurchaseException(
    this.message, {
    this.cancelled = false,
    this.pending = false,
  });
  final String message;
  final bool cancelled, pending;
}

abstract class ProPurchaseRepository {
  bool get enabled;
  String get unavailableMessage;
  Future<List<ProStoreProduct>> products();
  Future<ProAccess> purchase(ProBillingPeriod period);
  Future<ProAccess> restore();
  Future<ProAccess> synchronize();
}

/// La prueba del proveedor se habilita solo en móvil debug de desarrollo.
class ProPurchaseConfiguration {
  const ProPurchaseConfiguration({
    required this.key,
    required this.development,
    required this.debug,
    required this.mobile,
  });
  final String key;
  final bool development, debug, mobile;
  bool get enabled =>
      development &&
      debug &&
      mobile &&
      key.startsWith('test_') &&
      key.length > 5;
  String get unavailableMessage => !mobile
      ? 'Las compras de prueba se realizan desde la app móvil.'
      : !development || !debug
      ? 'Las compras de prueba están disponibles en la versión de desarrollo debug.'
      : 'Las compras de prueba están pendientes de configurar.';
}
