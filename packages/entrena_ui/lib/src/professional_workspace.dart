import 'package:flutter/material.dart';

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
    this.navigationWidth = 216,
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
        child: Scaffold(
          key: scaffoldKey,
          drawer: !desktop && showCompactNavigation && compactNavigation == null
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
                padding: EdgeInsets.only(left: desktop ? navigationWidth : 0),
                child: Column(
                  children: [
                    headerBuilder(context, desktop),
                    const Divider(height: 1),
                    Expanded(child: child),
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
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: cardWidth, child: child),
        ],
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
  });
  final String title;
  final List<T> items;
  final String Function(T) nameOf, subtitleOf;
  final String Function(T)? searchTextOf;
  final ValueChanged<T> onSelected;
  final Object? dragOwner;
  final bool enabled;
  final Widget? footer;
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
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final tile = ListTile(
                        title: Text(widget.nameOf(item)),
                        subtitle: Text(widget.subtitleOf(item)),
                        leading: widget.dragOwner == null
                            ? null
                            : const Icon(Icons.drag_indicator, size: 18),
                        onTap: widget.enabled
                            ? () => widget.onSelected(item)
                            : null,
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
class ProfessionalEditorWorkspace extends StatelessWidget {
  const ProfessionalEditorWorkspace({
    super.key,
    required this.library,
    required this.child,
    this.inspector,
  });
  final Widget library, child;
  final Widget? inspector;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!ProfessionalWorkspaceScope.isDesktop(context) ||
          constraints.maxWidth < 1000 ||
          !constraints.hasBoundedHeight) {
        return child;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: library),
          const VerticalDivider(width: 1),
          Expanded(child: child),
          if (inspector != null && constraints.maxWidth >= 1450) ...[
            const VerticalDivider(width: 1),
            SizedBox(width: 250, child: inspector),
          ],
        ],
      );
    },
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
      child: Builder(builder: builder),
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
