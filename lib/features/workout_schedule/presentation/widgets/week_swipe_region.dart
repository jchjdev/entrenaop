import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Gesto de presentación: las flechas y el deslizamiento comparten la acción.
class WeekSwipeRegion extends StatefulWidget {
  const WeekSwipeRegion({
    required this.child,
    required this.onChangeWeek,
    super.key,
  });
  final Widget child;
  final ValueChanged<int> onChangeWeek;

  @override
  State<WeekSwipeRegion> createState() => _WeekSwipeRegionState();
}

class _WeekSwipeRegionState extends State<WeekSwipeRegion> {
  double _distance = 0;

  bool _canStart(PointerEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final x = box.globalToLocal(event.position).dx;
    // El borde conserva el gesto de volver de la aplicación y del sistema.
    return x >= 24 && x <= box.size.width - 24;
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      _WeekSwipeRecognizer:
          GestureRecognizerFactoryWithHandlers<_WeekSwipeRecognizer>(
            () => _WeekSwipeRecognizer(),
            (recognizer) {
              recognizer.canStart = _canStart;
              recognizer.onStart = (_) => _distance = 0;
              recognizer.onUpdate = (details) =>
                  _distance += details.primaryDelta ?? 0;
              recognizer.onCancel = () => _distance = 0;
              recognizer.onEnd = (details) {
                final distance = _distance;
                _distance = 0;
                if (distance.abs() < 48 &&
                    (distance.abs() < 16 ||
                        (details.primaryVelocity ?? 0).abs() < 600)) {
                  return;
                }
                final direction =
                    Directionality.of(context) == TextDirection.ltr ? 1 : -1;
                widget.onChangeWeek(distance < 0 ? direction : -direction);
              };
            },
          ),
    },
    child: widget.child,
  );
}

class _WeekSwipeRecognizer extends HorizontalDragGestureRecognizer {
  late bool Function(PointerEvent) canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      canStart(event) && super.isPointerAllowed(event);
}
