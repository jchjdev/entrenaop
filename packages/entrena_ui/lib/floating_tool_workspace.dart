import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Herramienta no modal. Vive junto al navegador del área de trabajo para que
/// cambiar de ruta no cierre sus campos ni sustituya la pantalla que se edita.
class FloatingToolWorkspace extends StatefulWidget {
  const FloatingToolWorkspace({
    required this.title,
    required this.toolBuilder,
    required this.child,
    this.shortTitle,
    super.key,
  });

  final String title;
  final String? shortTitle;
  final WidgetBuilder toolBuilder;
  final Widget child;

  static VoidCallback? openerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolScope>()?.open;

  @override
  State<FloatingToolWorkspace> createState() => _FloatingToolWorkspaceState();
}

class _FloatingToolWorkspaceState extends State<FloatingToolWorkspace> {
  bool _opened = false;
  bool _minimized = false;
  bool _expanded = false;
  Offset? _position;
  final _headerFocus = FocusNode();

  @override
  void dispose() {
    _headerFocus.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    _opened = true;
    _minimized = false;
  });

  @override
  Widget build(BuildContext context) => _ToolScope(
    open: _open,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final left = media.padding.left + 8;
        final top = media.padding.top + 8;
        final right = math.max(
          left,
          constraints.maxWidth - media.padding.right - 8,
        );
        final bottom = math.max(
          top,
          constraints.maxHeight -
              math.max(media.padding.bottom, media.viewInsets.bottom) -
              8,
        );
        final width = math.min(_expanded ? 720.0 : 460.0, right - left);
        final height = math.min(_expanded ? 780.0 : 700.0, bottom - top);
        final headerHeight = math.min(64.0, height);
        final visibleHeight = _minimized ? headerHeight : height;
        final requested = _position ?? Offset(right - width, top + 64);
        final position = Offset(
          requested.dx.clamp(left, right - width),
          requested.dy.clamp(top, bottom - visibleHeight),
        );
        void move(Offset delta) => setState(() => _position = position + delta);

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_opened && width > 0 && height > 0)
              Positioned(
                left: position.dx,
                top: position.dy,
                width: width,
                height: visibleHeight,
                child: Material(
                  key: const ValueKey('floating-tool-window'),
                  elevation: 16,
                  color: Theme.of(context).colorScheme.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: Focus(
                                focusNode: _headerFocus,
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent &&
                                      event is! KeyRepeatEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  final delta = switch (event.logicalKey) {
                                    LogicalKeyboardKey.arrowLeft =>
                                      const Offset(-20, 0),
                                    LogicalKeyboardKey.arrowRight =>
                                      const Offset(20, 0),
                                    LogicalKeyboardKey.arrowUp => const Offset(
                                      0,
                                      -20,
                                    ),
                                    LogicalKeyboardKey.arrowDown =>
                                      const Offset(0, 20),
                                    _ => null,
                                  };
                                  if (delta == null) {
                                    return KeyEventResult.ignored;
                                  }
                                  move(delta);
                                  return KeyEventResult.handled;
                                },
                                child: Semantics(
                                  label: 'Mover ${widget.title}',
                                  hint: 'Arrastra la cabecera o usa las flechas del teclado',
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.move,
                                    child: GestureDetector(
                                      key: const ValueKey(
                                        'floating-tool-handle',
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _headerFocus.requestFocus,
                                      onPanStart: (_) =>
                                          _headerFocus.requestFocus(),
                                      onPanUpdate: (details) =>
                                          move(details.delta),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.drag_indicator,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                width < 380
                                                    ? widget.shortTitle ??
                                                          widget.title
                                                    : widget.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (constraints.maxWidth >= 600 && !_minimized)
                              IconButton(
                                tooltip: _expanded
                                    ? 'Restaurar tamaño'
                                    : 'Ampliar calculadora',
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                                icon: Icon(
                                  _expanded
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                ),
                              ),
                            IconButton(
                              tooltip: _minimized
                                  ? 'Restaurar calculadora'
                                  : 'Minimizar calculadora',
                              onPressed: () =>
                                  setState(() => _minimized = !_minimized),
                              icon: Icon(
                                _minimized
                                    ? Icons.open_in_full
                                    : Icons.minimize,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar calculadora',
                              onPressed: () => setState(() {
                                _opened = false;
                                _minimized = false;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Ocultar conserva campos y desplazamiento, pero retira
                      // los controles del foco y de la lectura accesible.
                      Expanded(
                        child: Offstage(
                          offstage: _minimized,
                          child: ExcludeFocus(
                            excluding: _minimized,
                            child: widget.toolBuilder(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ToolScope extends InheritedWidget {
  const _ToolScope({required this.open, required super.child});
  final VoidCallback open;

  @override
  bool updateShouldNotify(_ToolScope oldWidget) => false;
}
