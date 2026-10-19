import 'package:flutter/material.dart';

/// Los avisos editoriales orientan; solo los problemas de contenido bloquean.
class PublicationReviewPanel extends StatelessWidget {
  const PublicationReviewPanel({
    super.key,
    this.errors = const [],
    this.suggestions = const [],
  });
  final List<String> errors, suggestions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revisión antes de publicar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _line(
            context,
            errors.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
            errors.isEmpty
                ? 'Sin problemas detectados en las comprobaciones de contenido.'
                : 'Resuelve estos problemas antes de publicar.',
            error: errors.isNotEmpty,
          ),
          for (final message in errors)
            _line(context, Icons.block, message, error: true),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Sugerencias opcionales'),
            for (final message in suggestions)
              _line(context, Icons.info_outline, message),
          ],
          const SizedBox(height: 8),
          const Text(
            'Comprueba también que objetivos, dosis y condiciones sean adecuados. Estas comprobaciones no sustituyen tu revisión deportiva.',
          ),
        ],
      ),
    ),
  );

  Widget _line(
    BuildContext context,
    IconData icon,
    String message, {
    bool error = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: error
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
