import 'package:flutter/material.dart';

/// Arrastra tarjetas sobre el scroll del consumidor, también en el editor
/// incrustado. Una lista con scroll propio impediría desplazar el formulario.
class WorkoutReorderableCards extends StatefulWidget {
  const WorkoutReorderableCards({
    super.key,
    required this.identities,
    required this.itemBuilder,
    required this.feedbackBuilder,
    required this.onReorder,
    this.enabled = true,
    this.keyPrefix = 'workout-drag-handle',
    this.itemLabel = 'tarjeta',
  });
  final List<Object> identities;
  final Widget Function(BuildContext, int, Widget) itemBuilder;
  final Widget Function(BuildContext, int) feedbackBuilder;

  /// El destino es la posición final, una vez retirada la tarjeta original.
  final void Function(int from, int to) onReorder;
  final bool enabled;
  final String keyPrefix, itemLabel;

  @override
  State<WorkoutReorderableCards> createState() =>
      _WorkoutReorderableCardsState();
}

class _WorkoutReorderableCardsState extends State<WorkoutReorderableCards> {
  final _targets = <Object, GlobalKey>{};
  EdgeDraggingAutoScroller? _scroller;
  int? _dragging, _boundary;
  Offset? _pointer;

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    super.dispose();
  }

  int? _boundaryAt(Offset point) {
    for (var i = 0; i < widget.identities.length; i++) {
      final box = _targets[widget.identities[i]]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(point)) return point.dy < rect.center.dy ? i : i + 1;
    }
    return null;
  }

  void _highlight() {
    if (!mounted || _pointer == null) return;
    final boundary = _boundaryAt(_pointer!);
    if (boundary != _boundary) setState(() => _boundary = boundary);
  }

  void _start(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final scrollable = Scrollable.maybeOf(context);
    _scroller?.stopAutoScroll();
    _scroller = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(
            scrollable,
            velocityScalar: 12,
            onScrollViewScrolled: () {
              _highlight();
              _autoScroll();
            },
          );
    setState(() => _dragging = index);
  }

  void _autoScroll() {
    final pointer = _pointer;
    if (pointer != null) {
      _scroller?.startAutoScrollIfNecessary(
        Rect.fromCenter(center: pointer, width: 1, height: 80),
      );
    }
  }

  void _stop() {
    _scroller?.stopAutoScroll();
    if (mounted) {
      setState(() {
        _dragging = null;
        _boundary = null;
        _pointer = null;
      });
    }
  }

  void _accept(DragTargetDetails<int> details) {
    final boundary = _boundaryAt(details.offset);
    if (!widget.enabled || boundary == null || _dragging != details.data) {
      return;
    }
    final to = boundary > details.data ? boundary - 1 : boundary;
    if (to != details.data) widget.onReorder(details.data, to);
  }

  @override
  Widget build(BuildContext context) {
    _targets.removeWhere(
      (identity, _) => !widget.identities.contains(identity),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.identities.length; i++)
            DragTarget<int>(
              hitTestBehavior: HitTestBehavior.opaque,
              key: _targets.putIfAbsent(widget.identities[i], GlobalKey.new),
              onWillAcceptWithDetails: (details) =>
                  widget.enabled && _dragging == details.data,
              onMove: (details) {
                _pointer = details.offset;
                _highlight();
              },
              onAcceptWithDetails: _accept,
              builder: (context, candidates, rejected) {
                final icon = SizedBox(
                  width: 44,
                  height: 48,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
                Widget handle = MouseRegion(
                  cursor: widget.enabled
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.basic,
                  child: Tooltip(
                    message: 'Arrastrar ${widget.itemLabel} ${i + 1}',
                    child: icon,
                  ),
                );
                final feedback = Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: widget.feedbackBuilder(context, i),
                  ),
                );
                void update(DragUpdateDetails details) {
                  _pointer = details.globalPosition;
                  _highlight();
                  _autoScroll();
                }

                handle = Draggable<int>(
                  key: ValueKey('${widget.keyPrefix}-$i'),
                  data: i,
                  axis: Axis.vertical,
                  maxSimultaneousDrags: widget.enabled ? 1 : 0,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: feedback,
                  onDragStarted: () => _start(i),
                  onDragUpdate: update,
                  onDragEnd: (_) => _stop(),
                  child: handle,
                );
                return Stack(
                  children: [
                    Opacity(
                      opacity: _dragging == i ? .45 : 1,
                      child: widget.itemBuilder(context, i, handle),
                    ),
                    if (_dragging != null &&
                        (_boundary == i ||
                            i == widget.identities.length - 1 &&
                                _boundary == i + 1))
                      Positioned(
                        left: 4,
                        right: 4,
                        top: _boundary == i ? 0 : null,
                        bottom: _boundary == i ? null : 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 3,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
