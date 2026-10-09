import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/session_creation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryHubPage extends StatelessWidget {
  const LibraryHubPage({super.key});

  Future<void> _createSession(BuildContext context) async {
    final route = await chooseSessionEditor(context);
    if (route == null || !context.mounted) return;
    final created = await context.push<String>(route);
    if (created != null && context.mounted) {
      context.push('/plan/library?tab=personal');
    }
  }

  Future<void> _createExercise(BuildContext context) async {
    final created = await context.push<String>('/library/exercises/new');
    if (created != null && context.mounted) {
      context.push('/library/exercises?tab=personal');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const EntrenaWordmark(width: 164)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Biblioteca',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Encuentra sesiones y ejercicios. Haz espacio para los tuyos.',
                style: TextStyle(color: context.visuals.textMuted),
              ),
              const SizedBox(height: 26),
              _LibraryGroup(
                title: 'Sesiones',
                icon: Icons.layers_outlined,
                official: _CollectionCard(
                  title: 'Sesiones EntrenaOP',
                  description: 'Un buen punto de partida para entrenar.',
                  icon: Icons.layers_outlined,
                  primary: true,
                  onBrowse: () => context.push('/plan/library'),
                  browseLabel: 'Explorar sesiones',
                ),
                personal: _CollectionCard(
                  title: 'Mis sesiones',
                  description: 'Diseña y guarda tus propias sesiones.',
                  icon: Icons.edit_calendar_outlined,
                  onBrowse: () => context.push('/plan/library?tab=personal'),
                  browseLabel: 'Ver los míos',
                  createLabel: 'Crear sesión',
                  onCreate: () => _createSession(context),
                ),
              ),
              const SizedBox(height: 28),
              _LibraryGroup(
                title: 'Ejercicios',
                icon: Icons.fitness_center_outlined,
                official: _CollectionCard(
                  title: 'Ejercicios EntrenaOP',
                  description: 'Movimientos y técnica, en un mismo lugar.',
                  icon: Icons.fitness_center_outlined,
                  onBrowse: () => context.push('/library/exercises'),
                  browseLabel: 'Explorar ejercicios',
                ),
                personal: _CollectionCard(
                  title: 'Mis ejercicios',
                  description: 'Crea ejercicios y úsalos en tus sesiones.',
                  icon: Icons.fitness_center_outlined,
                  onBrowse: () =>
                      context.push('/library/exercises?tab=personal'),
                  browseLabel: 'Ver los míos',
                  createLabel: 'Crear ejercicio',
                  onCreate: () => _createExercise(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LibraryGroup extends StatelessWidget {
  const _LibraryGroup({
    required this.title,
    required this.icon,
    required this.official,
    required this.personal,
  });
  final String title;
  final IconData icon;
  final Widget official;
  final Widget personal;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: context.visuals.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680 ||
              MediaQuery.textScalerOf(context).scale(14) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [official, const SizedBox(height: 12), personal],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: official),
                const SizedBox(width: 14),
                Expanded(child: personal),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onBrowse,
    required this.browseLabel,
    this.primary = false,
    this.onCreate,
    this.createLabel,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onBrowse;
  final String browseLabel;
  final bool primary;
  final VoidCallback? onCreate;
  final String? createLabel;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    tone: primary ? EntrenaCardTone.accent : EntrenaCardTone.quiet,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (primary) ...[
              Text(
                'ENTRENAOP',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 21, color: context.visuals.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (primary)
          FilledButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(browseLabel),
          )
        else if (onCreate == null)
          OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(browseLabel),
          )
        else
          Builder(
            builder: (context) {
              final browse = OutlinedButton(
                onPressed: onBrowse,
                child: Text(browseLabel),
              );
              final create = OutlinedButton.icon(
                onPressed: onCreate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(createLabel!),
              );
              if (MediaQuery.sizeOf(context).width < 900 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [browse, const SizedBox(height: 8), create],
                );
              }
              return Row(
                children: [
                  Expanded(child: browse),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: create),
                ],
              );
            },
          ),
      ],
    ),
  );
}
