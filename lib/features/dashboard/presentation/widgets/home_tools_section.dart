import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeToolsSection extends StatelessWidget {
  const HomeToolsSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showHeading) ...[
        HomeSectionHeading(
          title: 'Para tus pruebas',
          action: TextButton(
            onPressed: () => context.push('/tools'),
            child: const Text('Ver todas'),
          ),
        ),
        const SizedBox(height: 10),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            const _ToolCard(
              icon: Icons.timer_outlined,
              title: 'Ritmos de carrera',
              description: 'Tiempos y parciales',
              route: '/tools/running-pace-calculator',
            ),
            const _ToolCard(
              icon: Icons.calculate_outlined,
              title: 'PAEF / PAFAS',
              description: 'Consulta de puntos · gratis',
              route: '/assessment/fas-calculator',
            ),
          ];
          if (constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(14) > 23) {
            return Column(
              children: [cards[0], const SizedBox(height: 10), cards[1]],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class HomeToolsPage extends StatelessWidget {
  const HomeToolsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Herramientas para tus pruebas')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const HomeToolsSection(showHeading: false),
        ),
      ),
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String description;
  final String route;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    onTap: () => context.push(route),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 27,
          ),
        ),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(color: context.visuals.textMuted, fontSize: 12),
        ),
      ],
    ),
  );
}
