import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:flutter/material.dart';

class AdminProgramsPage extends StatefulWidget {
  const AdminProgramsPage({
    super.key,
    required this.repository,
    required this.workoutRepository,
    required this.onSignOut,
  });

  final AdminProgramRepository repository;
  final AdminWorkoutRepository workoutRepository;
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
        title: const Text('Administración · programas'),
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
          'Programas',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Crea la identidad de una preparación o evaluación. Un borrador no aparece al alumno ni genera sesiones. Publicarlo requerirá contenido y revisión deportiva.',
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _createDraft,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo programa'),
          ),
        ),
        const SizedBox(height: 24),
        if (_programs.isEmpty)
          const Text('Todavía no hay programas.')
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
