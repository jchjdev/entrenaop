import 'package:flutter/material.dart';

/// Resumen compacto del tramo. Plegar solo cambia la presentación; los
/// controladores y la prescripción permanecen en el creador propietario.
class RunningStepCard extends StatelessWidget {
  const RunningStepCard({
    super.key,
    required this.index,
    required this.title,
    required this.summary,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.menu,
    required this.editor,
  });

  final int index;
  final String title, summary;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget menu, editor;

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
          Row(
            children: [
              Expanded(
                child: Semantics(
                  expanded: expanded,
                  child: InkWell(
                    key: ValueKey('running-step-header-$index'),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  summary,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              menu,
            ],
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: editor),
          ],
        ],
      ),
    ),
  );
}
