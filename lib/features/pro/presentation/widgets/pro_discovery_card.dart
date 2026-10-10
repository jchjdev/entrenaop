import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pro_offer.dart';

class ProDiscoveryCard extends StatelessWidget {
  const ProDiscoveryCard({
    this.offerContext = const ProOfferContext(),
    super.key,
  });

  final ProOfferContext offerContext;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PLAN ADAPTATIVO · PRO',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Un plan según tu preparación',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Entrenamientos que tienen en cuenta tus marcas, disponibilidad y resultados.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push(offerContext.location()),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Crear mi plan · Pro'),
        ),
        TextButton(
          onPressed: () => context.push(offerContext.location(example: true)),
          child: const Text('Ver un ejemplo'),
        ),
        Text(
          'Contratación próximamente disponible.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
