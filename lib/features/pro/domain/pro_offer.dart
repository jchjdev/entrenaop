/// Oferta de lanzamiento. Al conectar las tiendas, sus precios localizados
/// sustituirán estos importes antes de permitir cualquier compra.
enum ProBillingPeriod {
  annual('Anual', '29,99 €', 'año'),
  monthly('Mensual', '3,99 €', 'mes');

  const ProBillingPeriod(this.label, this.price, this.unit);
  final String label;
  final String price;
  final String unit;

  String get subscribeLabel => 'Suscribirme por $price/$unit';
  String get renewal => this == annual
      ? 'Se renueva automáticamente por 29,99 € cada año.'
      : 'Se renueva automáticamente por 3,99 € cada mes.';
}

/// Contexto de presentación, nunca una autorización para acceder a un programa.
class ProOfferContext {
  const ProOfferContext({this.goalId, this.preparationName});

  factory ProOfferContext.fromUri(Uri uri) => ProOfferContext(
    goalId: uri.queryParameters['goal'],
    preparationName: uri.queryParameters['preparation'],
  );

  final String? goalId;
  final String? preparationName;

  String location({bool example = false}) => Uri(
    path: example ? '/pro/example' : '/pro',
    queryParameters: {'goal': ?goalId, 'preparation': ?preparationName},
  ).toString();
}
