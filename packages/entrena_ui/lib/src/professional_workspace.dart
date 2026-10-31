import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'professional_theme.dart';

/// La presentación profesional no modifica permisos ni se activa en el deportista.
class ProfessionalWorkspaceScope extends InheritedWidget {
  const ProfessionalWorkspaceScope({
    super.key,
    required this.desktop,
    required super.child,
  });

  final bool desktop;

  static bool isDesktop(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProfessionalWorkspaceScope>()
          ?.desktop ??
      false;

  /// Solo las páginas de trabajo se expanden. Los diálogos y el acceso conservan
  /// sus límites propios, aunque el monitor sea grande.
  static BoxConstraints pageConstraints(
    BuildContext context, {
    double maxWidth = 1100,
  }) =>
      BoxConstraints(maxWidth: isDesktop(context) ? double.infinity : maxWidth);

  @override
  bool updateShouldNotify(ProfessionalWorkspaceScope oldWidget) =>
      desktop != oldWidget.desktop;
}

/// Marco común de los portales. El consumidor decide destinos y autorización.
class ProfessionalWorkspaceShell extends StatelessWidget {
  const ProfessionalWorkspaceShell({
    super.key,
    required this.scaffoldKey,
    required this.navigation,
    required this.child,
    required this.headerBuilder,
    this.compactNavigation,
    this.showCompactNavigation = true,
    this.navigationWidth = 208,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget navigation, child;
  final Widget Function(BuildContext context, bool desktop) headerBuilder;
  final Widget? compactNavigation;
  final bool showCompactNavigation;
  final double navigationWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      return ProfessionalWorkspaceScope(
        desktop: desktop,
        child: ProfessionalAppearance(
          enabled: desktop,
          child: Builder(
            builder: (context) => Scaffold(
              key: scaffoldKey,
              drawer:
                  !desktop && showCompactNavigation && compactNavigation == null
                  ? Drawer(
                      width: constraints.maxWidth.clamp(0, 320).toDouble(),
                      child: navigation,
                    )
                  : null,
              bottomNavigationBar: !desktop && showCompactNavigation
                  ? compactNavigation
                  : null,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: desktop ? navigationWidth : 0,
                    ),
                    child: Column(
                      // La ruta puede contener BlockSemantics: pintar la cabecera
                      // después mantiene accesibles herramientas y acciones.
                      verticalDirection: VerticalDirection.up,
                      children: [
                        Expanded(child: child),
                        const Divider(height: 1),
                        headerBuilder(context, desktop),
                      ],
                    ),
                  ),
                  // Los Navigator pueden bloquear semántica anterior. Dibujar la
                  // navegación después mantiene sus destinos accesibles.
                  if (desktop)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: navigationWidth,
                      child: navigation,
                    ),
                  if (desktop)
                    Positioned(
                      left: navigationWidth - 1,
                      top: 0,
                      bottom: 0,
                      child: const VerticalDivider(width: 1),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Rejilla sin scroll anidado: aprovecha el ancho dentro del scroll de la página.
class ProfessionalCatalogGrid extends StatelessWidget {
  const ProfessionalCatalogGrid({
    super.key,
    required this.children,
    this.minCardWidth = 300,
    this.spacing = 16,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minCardWidth, spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final count = ProfessionalWorkspaceScope.isDesktop(context)
          ? ((width + spacing) / (minCardWidth * scale + spacing))
                .floor()
                .clamp(1, maxColumns)
          : 1;
      final cardWidth = (width - spacing * (count - 1)) / count;
      return SizedBox(
        width: width,
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        ),
      );
    },
  );
}

/// Cabecera local: acciones visibles sin imponer una anchura fija al contenido.
class ProfessionalSectionHeader extends StatelessWidget {
  const ProfessionalSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!)],
        ],
      );
      final buttons = Wrap(spacing: 8, runSpacing: 8, children: actions);
      if (constraints.maxWidth < 800 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (actions.isNotEmpty) ...[const SizedBox(height: 16), buttons],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 24),
            Flexible(child: buttons),
          ],
        ],
      );
    },
  );
}

/// Origen local de un arrastre. La identidad evita cruces entre dos editores.
class ProfessionalLibraryDrag<T> {
  const ProfessionalLibraryDrag(this.owner, this.value);
  final Object owner;
  final T value;
}

/// Catálogo ya autorizado por su adaptador; buscar no amplía su alcance.
class ProfessionalLibraryPane<T> extends StatefulWidget {
  const ProfessionalLibraryPane({
    super.key,
    required this.title,
    required this.items,
    required this.nameOf,
    required this.subtitleOf,
    required this.onSelected,
    this.searchTextOf,
    this.dragOwner,
    this.enabled = true,
    this.footer,
    this.leadingOf,
    this.filters,
  });
  final String title;
  final List<T> items;
  final String Function(T) nameOf, subtitleOf;
  final String Function(T)? searchTextOf;
  final ValueChanged<T> onSelected;
  final Object? dragOwner;
  final bool enabled;
  final Widget? footer;
  final Widget Function(T)? leadingOf;
  final Widget? filters;
  @override
  State<ProfessionalLibraryPane<T>> createState() =>
      _ProfessionalLibraryPaneState<T>();
}

class _ProfessionalLibraryPaneState<T>
    extends State<ProfessionalLibraryPane<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (item) =>
              '${widget.nameOf(item)} ${widget.subtitleOf(item)} ${widget.searchTextOf?.call(item) ?? ''}'
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: widget.enabled,
                  decoration: const InputDecoration(
                    labelText: 'Buscar en la biblioteca',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                if (widget.filters != null) ...[
                  widget.filters!,
                  const SizedBox(height: 8),
                ],
                Text(
                  '${items.length} de ${widget.items.length} cargados',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay elementos que coincidan.'),
                  )
                : ListView.builder(
                    primary: false,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final tile = Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                        child: Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Tooltip(
                              message: widget.nameOf(item),
                              child: Text(
                                widget.nameOf(item),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            subtitle: Tooltip(
                              message: widget.subtitleOf(item),
                              child: Text(
                                widget.subtitleOf(item),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            leading: widget.leadingOf != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.dragOwner != null) ...[
                                        const Icon(
                                          Icons.drag_indicator,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      widget.leadingOf!(item),
                                    ],
                                  )
                                : widget.dragOwner == null
                                ? null
                                : const Icon(Icons.drag_indicator, size: 18),
                            onTap: widget.enabled
                                ? () => widget.onSelected(item)
                                : null,
                          ),
                        ),
                      );
                      if (widget.dragOwner == null || !widget.enabled) {
                        return tile;
                      }
                      return Draggable<ProfessionalLibraryDrag<T>>(
                        data: ProfessionalLibraryDrag(widget.dragOwner!, item),
                        maxSimultaneousDrags: 1,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 240,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(widget.nameOf(item)),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: .4, child: tile),
                        child: tile,
                      );
                    },
                  ),
          ),
          if (widget.footer != null)
            Padding(padding: const EdgeInsets.all(12), child: widget.footer!),
        ],
      ),
    );
  }
}

/// Composición común: biblioteca y zona de trabajo con scroll independiente.
/// En ancho reducido se mantiene el flujo y sus controles de añadir existentes.
class ProfessionalEditorWorkspace extends StatefulWidget {
  const ProfessionalEditorWorkspace({
    super.key,
    required this.library,
    required this.child,
    this.inspector,
    this.footer,
  });
  final Widget library, child;
  final Widget? inspector, footer;

  static bool hasInspector(BuildContext context, BoxConstraints constraints) =>
      ProfessionalWorkspaceScope.isDesktop(context) &&
      constraints.hasBoundedHeight &&
      constraints.maxWidth >= 1100;

  @override
  State<ProfessionalEditorWorkspace> createState() =>
      _ProfessionalEditorWorkspaceState();
}

class _ProfessionalEditorWorkspaceState
    extends State<ProfessionalEditorWorkspace> {
  double _libraryWidth = 196, _inspectorWidth = 400;
  final _content = GlobalKey();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          ProfessionalWorkspaceScope.isDesktop(context) &&
          constraints.hasBoundedHeight;
      final panels = desktop && constraints.maxWidth >= 900;
      final showInspector =
          widget.inspector != null &&
          ProfessionalEditorWorkspace.hasInspector(context, constraints);
      // Las preferencias locales nunca pueden aplastar el lienzo ni sus campos.
      // Al estrechar la ventana se acotan, sin perder el ancho elegido al volver.
      final space = constraints.maxWidth - 440 - (showInspector ? 24 : 12);
      final maxLibraryWidth = (space - (showInspector ? 320 : 0)).clamp(
        176.0,
        300.0,
      );
      final libraryWidth = panels
          ? _libraryWidth.clamp(176.0, maxLibraryWidth)
          : 196.0;
      final maxInspectorWidth = (space - libraryWidth).clamp(320.0, 560.0);
      final inspectorWidth = showInspector
          ? _inspectorWidth.clamp(320.0, maxInspectorWidth)
          : 400.0;
      final content = KeyedSubtree(key: _content, child: widget.child);
      final body = panels
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('professional-library-pane'),
                  width: libraryWidth,
                  child: widget.library,
                ),
                _ProfessionalResizeHandle(
                  key: const ValueKey('professional-library-resize'),
                  label: 'Ancho de la biblioteca',
                  width: libraryWidth,
                  minWidth: 176,
                  maxWidth: maxLibraryWidth,
                  onDelta: (delta) => setState(
                    () => _libraryWidth =
                        (_libraryWidth.clamp(176.0, maxLibraryWidth) + delta)
                            .clamp(176.0, maxLibraryWidth),
                  ),
                  onReset: () => setState(() => _libraryWidth = 196),
                ),
                Expanded(child: content),
                if (showInspector) ...[
                  _ProfessionalResizeHandle(
                    key: const ValueKey('professional-inspector-resize'),
                    label: 'Ancho de las propiedades',
                    width: inspectorWidth,
                    minWidth: 320,
                    maxWidth: maxInspectorWidth,
                    reverse: true,
                    onDelta: (delta) => setState(
                      () => _inspectorWidth =
                          (_inspectorWidth.clamp(320.0, maxInspectorWidth) -
                                  delta)
                              .clamp(320.0, maxInspectorWidth),
                    ),
                    onReset: () => setState(() => _inspectorWidth = 400),
                  ),
                  SizedBox(
                    key: const ValueKey('professional-inspector-pane'),
                    width: inspectorWidth,
                    child: widget.inspector,
                  ),
                ],
              ],
            )
          : content;
      if (!desktop || widget.footer == null) return body;
      return Column(
        children: [
          Expanded(child: body),
          const Divider(height: 1),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: widget.footer,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ResizePanelIntent extends Intent {
  const _ResizePanelIntent(this.delta);
  final double delta;
}

class _ProfessionalResizeHandle extends StatefulWidget {
  const _ProfessionalResizeHandle({
    super.key,
    required this.label,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onDelta,
    required this.onReset,
    this.reverse = false,
  });
  final String label;
  final double width, minWidth, maxWidth;
  final bool reverse;
  final ValueChanged<double> onDelta;
  final VoidCallback onReset;
  @override
  State<_ProfessionalResizeHandle> createState() =>
      _ProfessionalResizeHandleState();
}

class _ProfessionalResizeHandleState extends State<_ProfessionalResizeHandle> {
  final _focus = FocusNode();
  bool _highlight = false, _hover = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _highlight || _hover;
    return FocusableActionDetector(
      focusNode: _focus,
      mouseCursor: SystemMouseCursors.resizeColumn,
      onShowFocusHighlight: (value) => setState(() => _highlight = value),
      onShowHoverHighlight: (value) => setState(() => _hover = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _ResizePanelIntent(-24),
        SingleActivator(LogicalKeyboardKey.arrowRight): _ResizePanelIntent(24),
        SingleActivator(LogicalKeyboardKey.home): _ResizePanelIntent(0),
      },
      actions: {
        _ResizePanelIntent: CallbackAction<_ResizePanelIntent>(
          onInvoke: (intent) {
            if (intent.delta == 0) {
              widget.onReset();
            } else {
              widget.onDelta(intent.delta);
            }
            return null;
          },
        ),
      },
      child: Semantics(
        label: widget.label,
        value: '${widget.width.round()} píxeles',
        increasedValue:
            '${(widget.width + 24).clamp(widget.minWidth, widget.maxWidth).round()} píxeles',
        decreasedValue:
            '${(widget.width - 24).clamp(widget.minWidth, widget.maxWidth).round()} píxeles',
        onIncrease: () => widget.onDelta(widget.reverse ? -24 : 24),
        onDecrease: () => widget.onDelta(widget.reverse ? 24 : -24),
        child: Tooltip(
          message:
              '${widget.label}: arrastra o usa las flechas. Doble clic o Inicio para restablecer.',
          child: GestureDetector(
            dragStartBehavior: DragStartBehavior.down,
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            onDoubleTap: widget.onReset,
            onHorizontalDragStart: (_) => _focus.requestFocus(),
            onHorizontalDragUpdate: (event) => widget.onDelta(event.delta.dx),
            child: SizedBox(
              width: 12,
              child: ColoredBox(
                color: active
                    ? theme.colorScheme.primary.withValues(alpha: .1)
                    : Colors.transparent,
                child: Center(
                  child: Container(
                    width: active ? 3 : 1,
                    height: 48,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Propiedades con desplazamiento propio: el lienzo y las acciones siguen visibles.
class ProfessionalInspector extends StatelessWidget {
  const ProfessionalInspector({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(
      primary: false,
      key: const ValueKey('professional-inspector-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

/// Dos paneles relacionados, sin imponer scroll ni alturas al contenido.
class ProfessionalDetailColumns extends StatelessWidget {
  const ProfessionalDetailColumns({
    super.key,
    required this.primary,
    required this.secondary,
  });
  final Widget primary, secondary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!ProfessionalWorkspaceScope.isDesktop(context) ||
          constraints.maxWidth < 900) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 20), secondary],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: primary),
          const SizedBox(width: 24),
          Expanded(child: secondary),
        ],
      );
    },
  );
}

/// Los editores profesionales abiertos sobre el Navigator conservan el contexto
/// de escritorio sin trasladarlo a los diálogos de la app del deportista.
class ProfessionalWorkspaceViewport extends StatelessWidget {
  const ProfessionalWorkspaceViewport({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ProfessionalWorkspaceScope(
      desktop:
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24,
      child: Builder(
        builder: (context) => ProfessionalAppearance(
          enabled: ProfessionalWorkspaceScope.isDesktop(context),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// Un editor embebido necesita altura acotada para sus paneles de escritorio.
/// La clave conserva sus controladores al cambiar el tamaño de la ventana.
class ProfessionalEmbeddedScroll extends StatefulWidget {
  const ProfessionalEmbeddedScroll({super.key, required this.child});
  final Widget child;
  @override
  State<ProfessionalEmbeddedScroll> createState() =>
      _ProfessionalEmbeddedScrollState();
}

class _ProfessionalEmbeddedScrollState
    extends State<ProfessionalEmbeddedScroll> {
  final _content = GlobalKey();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = KeyedSubtree(key: _content, child: widget.child);
      return ProfessionalWorkspaceScope.isDesktop(context) &&
              constraints.maxWidth >= 1000 &&
              constraints.hasBoundedHeight
          ? content
          : SingleChildScrollView(child: content);
    },
  );
}

/// Pestaña de página con indicador discreto y activación por teclado.
class ProfessionalPageTab extends StatelessWidget {
  const ProfessionalPageTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de biblioteca: misma acción y permisos que aporta el consumidor.
class ProfessionalResourceCard extends StatelessWidget {
  const ProfessionalResourceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final desktop = ProfessionalWorkspaceScope.isDesktop(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: desktop
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 6)
            : EdgeInsets.zero,
        child: ListTile(
          title: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.titleMedium,
            child: title,
          ),
          subtitle: subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: subtitle,
                ),
          leading: leading,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}

class ProfessionalResourceIcon extends StatelessWidget {
  const ProfessionalResourceIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
  );
}
