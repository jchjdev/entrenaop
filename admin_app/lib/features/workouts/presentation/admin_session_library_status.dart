import 'package:flutter/material.dart';

import '../data/admin_workout_repository.dart';

class AdminSessionLibraryStatus extends StatelessWidget {
  const AdminSessionLibraryStatus({super.key, required this.session});

  final AdminWorkoutSummary? session;

  @override
  Widget build(BuildContext context) {
    final source = session;
    final listed =
        source?.showInLibrary == true && source?.catalogScope == 'general';
    final (icon, label) = switch (source?.status) {
      'published' when listed => (
        Icons.visibility_outlined,
        'Visible como sesión suelta',
      ),
      'published' => (
        Icons.visibility_off_outlined,
        'Oculta como sesión suelta',
      ),
      'draft' when listed => (
        Icons.schedule_outlined,
        'Se mostrará como sesión suelta al publicar',
      ),
      'draft' => (
        Icons.visibility_off_outlined,
        'No se mostrará como sesión suelta al publicar',
      ),
      'archived' => (
        Icons.visibility_off_outlined,
        'No visible · sesión retirada',
      ),
      _ => (Icons.help_outline, 'Visibilidad no disponible'),
    };
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
