import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/trainers/presentation/student_navigation.dart';

class AppAccountActions extends StatelessWidget {
  const AppAccountActions({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = StudentNavigationScope.maybeOf(context);
    if (navigation == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (navigation.unreadCount > 0)
          IconButton(
            tooltip: '${navigation.unreadCount} avisos sin leer',
            onPressed: () => context.go('/my-trainer?view=notices'),
            icon: Badge.count(
              count: navigation.unreadCount,
              maxCount: 99,
              backgroundColor: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        IconButton(
          tooltip: 'Mi perfil',
          onPressed: () => context.push('/profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
