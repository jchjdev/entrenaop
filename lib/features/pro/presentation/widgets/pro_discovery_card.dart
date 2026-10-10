import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pro_offer.dart';
import 'pro_access_widgets.dart';

class ProDiscoveryCard extends StatelessWidget {
  const ProDiscoveryCard({
    this.offerContext = const ProOfferContext(),
    this.loadAccess,
    super.key,
  });

  final ProOfferContext offerContext;
  final LoadProAccess? loadAccess;

  @override
  Widget build(BuildContext context) => loadAccess == null
      ? _card(context, false)
      : ProAccessBuilder(
          load: loadAccess!,
          builder: (context, access) => _card(context, access.isPro),
        );

  Widget _card(BuildContext context, bool isPro) => EntrenaCard(
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
          onPressed: () => context.push(
            isPro
                ? offerContext.goalId == null
                      ? '/plan/goal'
                      : '/plan/goal/${offerContext.goalId}/training'
                : offerContext.location(),
          ),
          icon: Icon(
            isPro ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
          ),
          label: Text(
            isPro
                ? offerContext.goalId == null
                      ? 'Elegir preparación'
                      : 'Configurar mi plan'
                : 'Crear mi plan · Pro',
          ),
        ),
        TextButton(
          onPressed: () => context.push(offerContext.location(example: true)),
          child: const Text('Ver un ejemplo'),
        ),
        Text(
          isPro
              ? 'Pro activo en tu cuenta.'
              : 'Contratación próximamente disponible.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
