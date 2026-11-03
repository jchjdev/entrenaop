import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// La semana pertenece al contexto consultado, no activa ni recalcula el plan.
String preparationContextLocation(
  String goalId, {
  required DateTime week,
  bool plan = false,
}) => Uri(
  pathSegments: ['', 'plan', 'goal', goalId, if (plan) 'plan'],
  queryParameters: {
    'week':
        '${week.year.toString().padLeft(4, '0')}-'
        '${week.month.toString().padLeft(2, '0')}-'
        '${week.day.toString().padLeft(2, '0')}',
  },
).toString();

/// Ficha y consulta son dos caras de la misma preparación. Reutilizar la cara
/// anterior evita el ciclo ficha → plan → otra ficha, conservando el origen.
void showPreparationContext(
  BuildContext context, {
  required String goalId,
  required DateTime week,
  bool plan = false,
}) {
  final router = GoRouter.of(context);
  final location = preparationContextLocation(goalId, week: week, plan: plan);
  final matches = router.routerDelegate.currentConfiguration;
  final current = matches.lastOrNull;
  final previous = current == null ? null : matches.remove(current).lastOrNull;
  if (previous?.matchedLocation == Uri.parse(location).path) {
    if (previous is ImperativeRouteMatch) {
      router.pop<DateTime>(week);
    } else {
      // Un enlace directo ya contiene a su padre declarativo. Actualizar ese
      // contexto conserva la semana elegida sin añadir otra copia del padre.
      router.go(location);
    }
  } else {
    // Una entrada desde Inicio/Entrenar/Gestionar conserva esa página debajo.
    unawaited(router.pushReplacement<DateTime>(location));
  }
}
