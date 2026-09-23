import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_preview_page.dart';
import 'package:flutter/material.dart';

class AdminProgramWorkoutsPage extends StatefulWidget {
  const AdminProgramWorkoutsPage({
    super.key,
    required this.program,
    required this.repository,
  });

  final AdminProgram program;
  final AdminWorkoutRepository repository;

  @override
  State<AdminProgramWorkoutsPage> createState() =>
      _AdminProgramWorkoutsPageState();
}

class _AdminProgramWorkoutsPageState extends State<AdminProgramWorkoutsPage> {
  List<AdminWorkoutSummary>? _workouts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final workouts = await widget.repository.listForProgram(
        widget.program.id,
      );
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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminWorkoutEditorPage(
          program: widget.program,
          repository: widget.repository,
        ),
      ),
    );
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
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminWorkoutPreviewPage(
          workout: workout,
          repository: widget.repository,
        ),
      ),
    );
    if (published == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión publicada en la biblioteca de la app.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.program.name)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sesiones del programa',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Biblioteca oficial de este programa. Guardar aquí no asigna sesiones ni modifica los planes de los alumnos.',
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
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ] else if (_workouts == null)
              const Center(child: CircularProgressIndicator())
            else if (_workouts!.isEmpty)
              const Text('Todavía no hay sesiones oficiales en este programa.')
            else
              for (final workout in _workouts!)
                Card(
                  child: ListTile(
                    onTap: () => _preview(workout),
                    leading: Icon(
                      workout.isRunning
                          ? Icons.directions_run
                          : Icons.fitness_center,
                    ),
                    title: Text(workout.name),
                    subtitle: Text(
                      workout.isRunning
                          ? 'Carrera · versión ${workout.version}'
                          : 'Fuerza · versión ${workout.version}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            workout.status == 'draft'
                                ? 'Borrador'
                                : 'Publicado',
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
