import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// El gesto depende del dispositivo de entrada, nunca del ancho o del zoom.
/// Ratón/trackpad arrastran al mover; el dedo conserva el scroll hasta mantener.
class TrainerPointerDrag<T extends Object> extends StatefulWidget {
  const TrainerPointerDrag({
    super.key,
    required this.data,
    required this.feedback,
    required this.child,
  });

  final T data;
  final Widget feedback, child;

  @override
  State<TrainerPointerDrag<T>> createState() => _TrainerPointerDragState<T>();
}

class _TrainerPointerDragState<T extends Object>
    extends State<TrainerPointerDrag<T>> {
  bool _dragging = false;

  void _started() {
    if (mounted) setState(() => _dragging = true);
  }

  void _ended(DraggableDetails _) {
    if (mounted) setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final source = MouseRegion(
      cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: widget.child,
    );
    final faded = Opacity(opacity: .35, child: source);
    return _TouchDrag<T>(
      data: widget.data,
      feedback: widget.feedback,
      childWhenDragging: faded,
      maxSimultaneousDrags: _dragging ? 0 : 1,
      onDragStarted: _started,
      onDragEnd: _ended,
      rootOverlay: true,
      child: _MouseDrag<T>(
        data: widget.data,
        feedback: widget.feedback,
        childWhenDragging: faded,
        maxSimultaneousDrags: _dragging ? 0 : 1,
        onDragStarted: _started,
        onDragEnd: _ended,
        rootOverlay: true,
        child: source,
      ),
    );
  }
}

class _MouseDrag<T extends Object> extends Draggable<T> {
  const _MouseDrag({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.maxSimultaneousDrags,
    required super.onDragStarted,
    required super.onDragEnd,
    required super.rootOverlay,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: const {
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
    },
    allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
  )..onStart = onStart;
}

class _TouchDrag<T extends Object> extends LongPressDraggable<T> {
  const _TouchDrag({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.maxSimultaneousDrags,
    required super.onDragStarted,
    required super.onDragEnd,
    required super.rootOverlay,
    required super.child,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      DelayedMultiDragGestureRecognizer(
          delay: delay,
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.unknown,
          },
        )
        ..onStart = (position) {
          final drag = onStart(position);
          if (drag != null && hapticFeedbackOnStart) {
            HapticFeedback.selectionClick();
          }
          return drag;
        };
}
