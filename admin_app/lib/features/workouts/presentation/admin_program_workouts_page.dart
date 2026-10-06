import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/core/catalog_search.dart';
import 'package:flutter/material.dart';

class AdminProgramWorkoutsPage extends StatefulWidget {
  const AdminProgramWorkoutsPage({
    super.key,
    required this.program,
    required this.repository,
  });

  final AdminProgram? program;
  final AdminWorkoutRepository repository;

  @override
  State<AdminProgramWorkoutsPage> createState() =>
      _AdminProgramWorkoutsPageState();
}

class _AdminProgramWorkoutsPageState extends State<AdminProgramWorkoutsPage> {
  List<AdminWorkoutSummary>? _workouts;
  String? _error;
  String _filter = 'all';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _routeBase => widget.program == null
      ? '/sessions'
      : '/programs/${Uri.encodeComponent(widget.program!.id)}/sessions';

  List<AdminWorkoutSummary> get _visibleWorkouts => _workouts == null
      ? const []
      : _workouts!
            .where(
              (workout) =>
                  (_filter == 'all' || workout.status == _filter) &&
                  matchesCatalogSearch(_search.text, [
                    workout.name,
                    workout.isRunning ? 'Carrera' : 'Fuerza',
                  ]),
            )
            .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final workouts = widget.program == null
          ? await widget.repository.listGeneral()
          : await widget.repository.listForProgram(widget.program!.id);
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar las sesiones.');
      }
    }
  }

  Future<void> _create() async {
    final saved = await context.push<bool>('$_routeBase/new');
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión oficial guardada como borrador.'),
          ),
        );
      }
    }
  }

  Future<void> _preview(AdminWorkoutSummary workout) async {
    await context.push<bool>('$_routeBase/${Uri.encodeComponent(workout.id)}');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.program?.name ?? 'Biblioteca general'),
      leading: GoRouter.maybeOf(context)?.canPop() == false
          ? IconButton(
              tooltip: 'Ir a programas',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.go('/programs'),
            )
          : null,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.program == null
                  ? 'Sesiones generales de EntrenaOP'
                  : 'Sesiones del programa',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.program == null
                  ? 'Solo las sesiones publicadas aquí aparecerán en la biblioteca general de la app.'
                  : 'Estas plantillas pertenecen a este programa. Publicarlas no las muestra en la biblioteca general ni las asigna a alumnos.',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Nueva sesión'),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar sesiones',
                hintText: 'Nombre, carrera o fuerza',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (_workouts != null && _workouts!.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final (value, label) in [
                    ('all', 'Todas'),
                    ('draft', 'Borradores'),
                    ('published', 'Publicadas'),
                    ('archived', 'Retiradas'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ] else if (_workouts == null)
              const Center(child: CircularProgressIndicator())
            else if (_workouts!.isEmpty)
              const Text('Todavía no hay sesiones en esta biblioteca.')
            else if (_visibleWorkouts.isEmpty)
              const Text('No hay sesiones con esta búsqueda y estado.')
            else
              for (final workout in _visibleWorkouts)
                Card(
                  child: ListTile(
                    onTap: () => _preview(workout),
                    leading: Icon(
                      workout.isRunning
                          ? Icons.directions_run
                          : Icons.fitness_center,
                    ),
                    title: Text(workout.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            workout.isRunning
                                ? 'Carrera · versión ${workout.version}'
                                : 'Fuerza · versión ${workout.version}',
                          ),
                          Chip(
                            label: Text(switch (workout.status) {
                              'draft' => 'Borrador',
                              'published' => 'Publicado',
                              'archived' => 'Retirado',
                              _ => workout.status,
                            }),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
