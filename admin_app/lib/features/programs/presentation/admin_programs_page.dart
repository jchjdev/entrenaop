import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:flutter/material.dart';

class AdminProgramsPage extends StatefulWidget {
  const AdminProgramsPage({
    super.key,
    required this.repository,
    required this.workoutRepository,
    required this.exerciseRepository,
    required this.onSignOut,
  });

  final AdminProgramRepository repository;
  final AdminWorkoutRepository workoutRepository;
  final AdminExerciseRepository exerciseRepository;
  final VoidCallback onSignOut;

  @override
  State<AdminProgramsPage> createState() => _AdminProgramsPageState();
}

class _AdminProgramsPageState extends State<AdminProgramsPage> {
  bool _loading = true;
  bool _authorized = false;
  bool _saving = false;
  String? _error;
  List<AdminProgram> _programs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authorized = await widget.repository.hasAccess();
      if (!mounted) return;
      if (!authorized) {
        setState(() {
          _authorized = false;
          _loading = false;
        });
        return;
      }
      final programs = await widget.repository.listPrograms();
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _programs = programs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el área de administración.';
        _loading = false;
      });
    }
  }

  Future<void> _createDraft() async {
    final result = await showDialog<({String name, String kind})>(
      context: context,
      builder: (_) => const _NewProgramDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createDraft(name: result.name, kind: result.kind);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programa guardado como borrador.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo crear el programa. Comprueba el permiso y la conexión.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const CircularProgressIndicator();
    if (_error != null) {
      return _Message(_error!, onRetry: _load);
    }
    if (!_authorized) {
      return const _Message('Esta cuenta no tiene permiso de administración.');
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '¿Qué quieres gestionar?',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige el catálogo de contenido de EntrenaOP en el que quieres trabajar.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AdminAreaCard(
              icon: Icons.account_tree_outlined,
              title: 'Programas',
              description: 'Crear una preparación o evaluación.',
              action: 'Crear programa',
              onTap: _saving ? null : _createDraft,
            ),
            _AdminAreaCard(
              icon: Icons.view_agenda_outlined,
              title: 'Sesiones oficiales',
              description: 'Crear sesiones para la biblioteca general.',
              action: 'Abrir sesiones',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminProgramWorkoutsPage(
                    program: null,
                    repository: widget.workoutRepository,
                  ),
                ),
              ),
            ),
            _AdminAreaCard(
              icon: Icons.fitness_center,
              title: 'Ejercicios oficiales',
              description: 'Crear y editar el catálogo global.',
              action: 'Abrir ejercicios',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AdminExercisesPage(repository: widget.exerciseRepository),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Programas existentes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _createDraft,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo programa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada programa agrupa sus propias sesiones. Los borradores no aparecen en la aplicación del deportista.',
        ),
        const SizedBox(height: 16),
        if (_programs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Todavía no hay programas.'),
            ),
          )
        else
          for (final program in _programs)
            Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminProgramWorkoutsPage(
                      program: program,
                      repository: widget.workoutRepository,
                    ),
                  ),
                ),
                title: Text(program.name),
                subtitle: Text(
                  program.kind == 'access'
                      ? 'Acceso u oposición'
                      : 'Evaluación interna',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(program.enabled ? 'Publicado' : 'Borrador'),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _AdminAreaCard extends StatelessWidget {
  const _AdminAreaCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 268,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ],
    ),
  );
}

class _NewProgramDialog extends StatefulWidget {
  const _NewProgramDialog();

  @override
  State<_NewProgramDialog> createState() => _NewProgramDialogState();
}

class _NewProgramDialogState extends State<_NewProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _kind = 'access';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuevo programa'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Escribe al menos 3 caracteres.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                  value: 'access',
                  child: Text('Acceso u oposición'),
                ),
                DropdownMenuItem(
                  value: 'internal_assessment',
                  child: Text('Evaluación interna'),
                ),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se guardará como borrador. No será visible para alumnos.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop((name: _name.text.trim(), kind: _kind));
        },
        child: const Text('Crear borrador'),
      ),
    ],
  );
}
