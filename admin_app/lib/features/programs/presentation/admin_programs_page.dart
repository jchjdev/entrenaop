import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/core/catalog_search.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';

class AdminProgramsPage extends StatefulWidget {
  const AdminProgramsPage({
    super.key,
    required this.repository,
    required this.workoutRepository,
    required this.exerciseRepository,
    required this.onSignOut,
    this.coverRepository,
  });

  final AdminProgramRepository repository;
  final AdminWorkoutRepository workoutRepository;
  final AdminExerciseRepository exerciseRepository;
  final VoidCallback onSignOut;
  final ProgramCoverRepository? coverRepository;

  @override
  State<AdminProgramsPage> createState() => _AdminProgramsPageState();
}

class _AdminProgramsPageState extends State<AdminProgramsPage> {
  bool _loading = true;
  bool _authorized = false;
  bool _saving = false;
  String? _error;
  List<AdminProgram> _programs = const [];
  final _search = TextEditingController();
  List<AdminProgram> get _visiblePrograms => _programs
      .where(
        (program) => matchesCatalogSearch(_search.text, [
          program.name,
          program.kind == 'access' ? 'Acceso oposición' : 'Evaluación interna',
          program.enabled ? 'Publicado' : 'Borrador',
        ]),
      )
      .toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _programs.isEmpty;
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
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<({String name, String kind})>(
        save: (value) =>
            widget.repository.createDraft(name: value.name, kind: value.kind),
        errorMessage: 'No se pudo crear el programa. Tus datos siguen aquí; revisa permisos y conexión.',
        builder: (context, submit, saving, error, markDirty) =>
            _NewProgramDialog(
              onSubmit: submit,
              saving: saving,
              error: error,
              onDirtyChanged: markDirty,
            ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
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
        title: const Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EntrenaWordmark(width: 132),
            Text('Administración', style: TextStyle(fontSize: 14)),
          ],
        ),
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
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const CircularProgressIndicator();
    if (_error != null && _programs.isEmpty) {
      return _Message(_error!, onRetry: _load);
    }
    if (!_authorized) {
      return const _Message('Esta cuenta no tiene permiso de administración.');
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '¿Qué quieres gestionar?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Elige el catálogo de contenido de EntrenaOP en el que quieres trabajar.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 840
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AdminAreaCard(
                  width: width,
                  icon: Icons.account_tree_outlined,
                  title: 'Programas',
                  description: 'Crear una preparación o evaluación.',
                  action: 'Crear programa',
                  onTap: _saving ? null : _createDraft,
                ),
                _AdminAreaCard(
                  width: width,
                  icon: Icons.view_agenda_outlined,
                  title: 'Sesiones oficiales',
                  description: 'Crear sesiones para la biblioteca general.',
                  action: 'Abrir sesiones',
                  onTap: () => context.push('/sessions'),
                ),
                _AdminAreaCard(
                  width: width,
                  icon: Icons.fitness_center,
                  title: 'Ejercicios oficiales',
                  description: 'Crear y editar el catálogo global.',
                  action: 'Abrir ejercicios',
                  onTap: () => context.push('/exercises'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            title: const Text('Laboratorio de fuerza y rendimiento'),
            subtitle: const Text(
              'Revisar selección, dosis y respuesta con datos simulados',
            ),
            leading: const Icon(Icons.science_outlined),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => context.push('/laboratory'),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Programas existentes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _createDraft,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo programa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cada programa agrupa sus propias sesiones. Los borradores no aparecen en la aplicación del deportista.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar programas',
            prefixIcon: Icon(Icons.search),
            hintText: 'Nombre, tipo o estado',
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Reintentar')),
        if (_programs.isNotEmpty && _visiblePrograms.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay programas con esa búsqueda.'),
          ),
        if (_programs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Todavía no hay programas.'),
            ),
          )
        else
          for (final program in _visiblePrograms)
            Card(
              child: ListTile(
                onTap: () async {
                  await context.push(
                    '/programs/${Uri.encodeComponent(program.id)}',
                  );
                  if (mounted) await _load();
                },
                title: Text(program.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        program.kind == 'access'
                            ? 'Acceso u oposición'
                            : 'Evaluación interna',
                      ),
                      Chip(
                        avatar: Icon(
                          program.enabled
                              ? Icons.check_circle_outline
                              : Icons.edit_note_rounded,
                          size: 16,
                          color: program.enabled
                              ? context.visuals.success
                              : context.visuals.textMuted,
                        ),
                        label: Text(program.enabled ? 'Publicado' : 'Borrador'),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
      ],
    );
  }
}

class _AdminAreaCard extends StatelessWidget {
  const _AdminAreaCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final double width;
  final String title;
  final String description;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: EntrenaCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.visuals.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 26,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(color: context.visuals.textMuted)),
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
  const _NewProgramDialog({
    required this.onSubmit,
    required this.saving,
    required this.onDirtyChanged,
    this.error,
  });
  final ValueChanged<({String name, String kind})> onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final bool saving;
  final String? error;

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
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: AbsorbPointer(
        absorbing: widget.saving,
        child: Form(
          key: _formKey,
          onChanged: () =>
              widget.onDirtyChanged(_name.text.isNotEmpty || _kind != 'access'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.error != null)
                Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (widget.saving) const LinearProgressIndicator(),
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
    ),
    actions: [
      TextButton(
        onPressed: widget.saving
            ? null
            : () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: widget.saving
            ? null
            : () {
                if (!_formKey.currentState!.validate()) return;
                widget.onSubmit((name: _name.text.trim(), kind: _kind));
              },
        child: const Text('Crear borrador'),
      ),
    ],
  );
}
