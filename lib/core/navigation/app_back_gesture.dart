import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Añade el mismo gesto de borde a Android, iOS y web, sin cambiar el tema visual.
ThemeData withAppBackGesture(ThemeData theme) => theme.copyWith(
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      ...theme.pageTransitionsTheme.builders,
      TargetPlatform.android: const AppBackPageTransitionsBuilder(),
      TargetPlatform.iOS: const AppBackPageTransitionsBuilder(),
      if (kIsWeb)
        for (final platform in TargetPlatform.values)
          platform: const AppBackPageTransitionsBuilder(),
    },
  ),
);

class AppBackPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const AppBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _ProtectedBackGesture(
    route: route,
    child: super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    ),
  );
}

/// PopScope y las rutas con onExit desactivan el gesto interactivo. El borde solicita
/// la salida a go_router, que conserva onExit, el borrador y las confirmaciones.
/// Las consultas siguen usando el gesto interactivo nativo de Cupertino.
class _ProtectedBackGesture extends StatefulWidget {
  const _ProtectedBackGesture({required this.route, required this.child});
  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_ProtectedBackGesture> createState() => _ProtectedBackGestureState();
}

class _ProtectedBackGestureState extends State<_ProtectedBackGesture> {
  double _distance = 0;

  bool get _canStart =>
      widget.route.isCurrent &&
      widget.route.canPop &&
      !widget.route.fullscreenDialog &&
      widget.route.animation?.status == AnimationStatus.completed &&
      !widget.route.popGestureEnabled &&
      (GoRouter.maybeOf(context)?.canPop() ?? false);

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: 24,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _ProtectedBackRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _ProtectedBackRecognizer
                  >(() => _ProtectedBackRecognizer(), (recognizer) {
                    recognizer.canStart = () => _canStart;
                    recognizer.onStart = (_) => _distance = 0;
                    recognizer.onUpdate = (details) =>
                        _distance += (details.primaryDelta ?? 0) * direction;
                    recognizer.onCancel = () => _distance = 0;
                    recognizer.onEnd = (details) {
                      final velocity =
                          (details.primaryVelocity ?? 0) * direction;
                      final completed =
                          _distance >= 72 ||
                          (_distance >= 24 && velocity >= 650);
                      _distance = 0;
                      if (completed && _canStart) {
                        GoRouter.of(context).pop();
                      }
                    };
                  }),
            },
          ),
        ),
      ],
    );
  }
}

class _ProtectedBackRecognizer extends HorizontalDragGestureRecognizer {
  late bool Function() canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      canStart() && super.isPointerAllowed(event);
}
