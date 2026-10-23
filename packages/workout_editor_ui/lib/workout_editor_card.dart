import 'package:flutter/material.dart';

/// Tarjeta común de autoría de carrera y fuerza. Plegar solo cambia la presentación; los
/// controladores y la prescripción permanecen en el creador propietario.
class WorkoutEditorCard extends StatelessWidget {
  const WorkoutEditorCard({
    super.key,
    required this.index,
    required this.title,
    required this.summary,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.menu,
    required this.editor,
    this.dragHandle,
    this.headerKeyPrefix = 'workout-card-header',
  });

  final int index;
  final String title, summary;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget menu, editor;
  final Widget? dragHandle;
  final String headerKeyPrefix;

  Widget _text(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(
        summary,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _header(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // En móvil o con texto grande, las acciones no deben estrechar el resumen
      // hasta partir cada palabra. Siguen disponibles en una fila independiente.
      if (constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ?dragHandle,
                const SizedBox(width: 14),
                Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: color),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onToggle,
                  tooltip: expanded ? 'Plegar' : 'Desplegar',
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
                menu,
              ],
            ),
            Semantics(
              expanded: expanded,
              child: InkWell(
                key: ValueKey('$headerKeyPrefix-$index'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _text(context),
                ),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          ?dragHandle,
          Expanded(
            child: Semantics(
              expanded: expanded,
              child: InkWell(
                key: ValueKey('$headerKeyPrefix-$index'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _text(context)),
                      const SizedBox(width: 4),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
          menu,
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    clipBehavior: Clip.antiAlias,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: editor),
          ],
        ],
      ),
    ),
  );
}
