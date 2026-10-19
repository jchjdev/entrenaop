import 'package:flutter/material.dart';
import 'package:workout_core/guided_program.dart';

class AdminGuidedProgramCard extends StatelessWidget {
  const AdminGuidedProgramCard({
    super.key,
    required this.program,
    required this.onEdit,
    required this.onPublish,
    required this.onRetire,
    this.onCover,
  });

  final GuidedProgram program;
  final VoidCallback? onEdit, onPublish, onRetire, onCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = program;
    final status = switch (p.status) {
      'draft' => 'Borrador',
      'published' => 'Publicado',
      'archived' => 'Retirado',
      _ => p.status,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    p.mode == GuidedProgramMode.guide
                        ? Icons.repeat_rounded
                        : Icons.route_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${p.modeLabel} · versión ${p.version}'),
                          Chip(
                            avatar: Icon(
                              p.status == 'published'
                                  ? Icons.check_circle_outline
                                  : p.status == 'draft'
                                  ? Icons.edit_note
                                  : Icons.archive_outlined,
                              size: 16,
                            ),
                            label: Text(status),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            Text(
              '${p.sessionCount} sesiones${p.mode == GuidedProgramMode.phased ? ' · ${p.phases.length} fases' : ' · Secuencia repetible'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (p.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in p.categories)
                    Chip(
                      label: Text(c.name),
                      avatar: c.id == p.primaryCategoryId
                          ? const Icon(Icons.star_outline, size: 16)
                          : null,
                    ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    p.status == 'draft' ? 'Editar borrador' : 'Crear revisión',
                  ),
                ),
                if (p.status == 'draft')
                  OutlinedButton.icon(
                    onPressed: onPublish,
                    icon: const Icon(Icons.publish_outlined, size: 18),
                    label: const Text('Publicar'),
                  ),
                if (onCover != null)
                  TextButton.icon(
                    onPressed: onCover,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Portada'),
                  ),
                if (p.status == 'published')
                  PopupMenuButton<String>(
                    enabled: onRetire != null,
                    tooltip: 'Más opciones de ${p.name}',
                    onSelected: (_) => onRetire?.call(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'retire',
                        child: Text('Retirar del catálogo'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
