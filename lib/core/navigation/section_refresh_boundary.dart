import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Actualiza una consulta al volver a verla sin desmontar la rama ni su estado.
/// La carga inicial y los errores siguen perteneciendo a cada pantalla/Cubit.
class SectionRefreshBoundary extends StatefulWidget {
  const SectionRefreshBoundary({
    required this.location,
    required this.onVisible,
    required this.child,
    super.key,
  });

  final String location;
  final Future<void> Function() onVisible;
  final Widget child;

  @override
  State<SectionRefreshBoundary> createState() => _SectionRefreshBoundaryState();
}

class _SectionRefreshBoundaryState extends State<SectionRefreshBoundary> {
  GoRouter? _router;
  bool _visible = false;
  bool _scheduled = false;

  bool get _isVisible => _router?.state.uri.path == widget.location;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (_router == router) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _visible = _isVisible;
    _router?.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    final visible = _isVisible;
    final returned = visible && !_visible;
    _visible = visible;
    if (!returned || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_isVisible) return;
      // Las vistas presentan el fallo con su estado de error/reintento.
      unawaited(widget.onVisible().catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
