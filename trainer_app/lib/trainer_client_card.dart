import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

enum TrainerClientAction { history, deactivate, archive, restore }

class TrainerClientCard extends StatelessWidget {
  const TrainerClientCard({
    super.key,
    required this.client,
    required this.busy,
    required this.onManage,
    this.onOpen,
    this.onTechnique,
    this.techniqueMode = false,
  });

  final TrainerClient client;
  final bool busy, techniqueMode;
  final VoidCallback? onOpen, onTechnique;
  final ValueChanged<TrainerClientAction> onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = client.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Text(initials.isEmpty ? '?' : initials)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      client.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!techniqueMode)
                    PopupMenuButton<TrainerClientAction>(
                      tooltip: 'Opciones de ${client.name}',
                      enabled: !busy,
                      onSelected: onManage,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: TrainerClientAction.history,
                          child: Text('Historial del vínculo'),
                        ),
                        if (client.active)
                          const PopupMenuItem(
                            value: TrainerClientAction.deactivate,
                            child: Text('Desactivar servicio'),
                          )
                        else
                          PopupMenuItem(
                            value: client.archivedAt == null
                                ? TrainerClientAction.archive
                                : TrainerClientAction.restore,
                            child: Text(
                              client.archivedAt == null
                                  ? 'Archivar cliente'
                                  : 'Recuperar cliente',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      client.active
                          ? Icons.check_circle_outline
                          : Icons.history,
                      size: 16,
                    ),
                    label: Text(
                      client.active
                          ? 'Activo'
                          : client.archivedAt != null
                          ? 'Archivado'
                          : 'Inactivo',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                client.active
                    ? 'Desde el ${trainerDate(client.acceptedAt)}'
                    : 'Inactivo desde el ${trainerDate(client.endedAt ?? client.updatedAt)}',
              ),
              const SizedBox(height: 4),
              Text(
                '${client.episodeCount} ${client.episodeCount == 1 ? 'etapa de seguimiento' : 'etapas de seguimiento'}',
                style: theme.textTheme.bodySmall,
              ),
              if (!client.active) ...[
                const SizedBox(height: 8),
                const Text(
                  'No ocupa plaza. Su ficha e historial se conservan.',
                ),
              ],
              const SizedBox(height: 16),
              if (onOpen != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        techniqueMode
                            ? 'Elegir alumno y consultar sesiones'
                            : 'Abrir ficha',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              if (!techniqueMode && onTechnique != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : onTechnique,
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Vídeos de técnica'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
