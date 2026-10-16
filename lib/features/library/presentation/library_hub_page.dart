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
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(title: const EntrenaWordmark(width: 164)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biblioteca',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Todo para entrenar.',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  tabs: [
                    Tab(text: 'Sesiones'),
                    Tab(text: 'Ejercicios'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _LibraryGroup(
                      storageKey: 'library-sessions',
                      official: _CollectionCard(
                        title: 'Sesiones EntrenaOP',
                        description: 'Listas para entrenar.',
                        icon: Icons.layers_outlined,
                        primary: true,
                        onBrowse: () => context.push('/plan/library'),
                        browseLabel: 'Explorar sesiones',
                      ),
                      personal: _CollectionCard(
                        title: 'Mis sesiones',
                        description: 'Creadas por ti.',
                        icon: Icons.edit_calendar_outlined,
                        onBrowse: () =>
                            context.push('/plan/library?tab=personal'),
                        browseLabel: 'Ver las mías',
                        createLabel: 'Crear sesión',
                        onCreate: () => _createSession(context),
                      ),
                    ),
                    _LibraryGroup(
                      storageKey: 'library-exercises',
                      official: _CollectionCard(
                        title: 'Ejercicios EntrenaOP',
                        description: 'Técnica y práctica.',
                        icon: Icons.fitness_center_outlined,
                        onBrowse: () => context.push('/library/exercises'),
                        browseLabel: 'Explorar ejercicios',
                      ),
                      personal: _CollectionCard(
                        title: 'Mis ejercicios',
                        description: 'Creados por ti.',
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
            ],
          ),
        ),
      ),
    ),
  );
}

class _LibraryGroup extends StatelessWidget {
  const _LibraryGroup({
    required this.storageKey,
    required this.official,
    required this.personal,
  });
  final String storageKey;
  final Widget official;
  final Widget personal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final vertical =
          constraints.maxWidth < 680 ||
          MediaQuery.textScalerOf(context).scale(14) > 22;
      return CustomScrollView(
        key: PageStorageKey(storageKey),
        slivers: [
          SliverFillRemaining(
            // Las dos tarjetas comparten el alto útil. Solo hay recorrido
            // vertical si su contenido legible supera realmente la pestaña.
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: vertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: official),
                        const SizedBox(height: 12),
                        Expanded(child: personal),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: official),
                        const SizedBox(width: 14),
                        Expanded(child: personal),
                      ],
                    ),
            ),
          ),
        ],
      );
    },
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
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
        const SizedBox(height: 8),
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
