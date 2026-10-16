import 'package:flutter/material.dart';

import 'exercise_reference_video.dart';

/// Ficha de consulta compartida. El contexto decide si ofrece edición.
class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet({
    super.key,
    required this.name,
    this.description,
    this.imageUrl,
    this.videoUrl,
    this.subtitle,
    this.sessionInstructions,
    this.muscleGroups = const [],
    this.equipment = const [],
    this.onEdit,
  });
  final String name;
  final String? description, imageUrl, videoUrl, subtitle, sessionInstructions;
  final List<String> muscleGroups, equipment;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar detalle',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            if (imageUrl?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl!,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              description?.trim().isNotEmpty == true
                  ? description!
                  : 'Este ejercicio aún no tiene una descripción.',
              style: const TextStyle(height: 1.5),
            ),
            if (sessionInstructions?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 18),
              Text(
                'Indicaciones de esta serie',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(sessionInstructions!, style: const TextStyle(height: 1.5)),
            ],
            if (muscleGroups.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Grupos musculares',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(muscleGroups.join(' · ')),
            ],
            if (equipment.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Material', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 5),
              Text(equipment.join(' · ')),
            ],
            if (videoUrl?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 18),
              ExerciseReferenceVideo(url: videoUrl!),
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar ejercicio'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
