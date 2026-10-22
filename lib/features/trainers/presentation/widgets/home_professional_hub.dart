import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:flutter/material.dart';

import '../student_navigation.dart';

/// Inicio resume las novedades; el seguimiento completo vive en Preparador.
class HomeProfessionalHub extends StatelessWidget {
  const HomeProfessionalHub({super.key, required this.onOpen});

  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    final count = StudentNavigationScope.maybeOf(context)?.unreadCount ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: EntrenaCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(
            '$count ${count == 1 ? 'novedad de tu preparador' : 'novedades de tu preparador'}',
          ),
          subtitle: const Text('Consultar avisos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpen('/my-trainer?view=notices'),
        ),
      ),
    );
  }
}
