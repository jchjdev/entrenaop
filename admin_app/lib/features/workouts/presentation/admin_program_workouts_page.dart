import 'package:workout_editor_ui/workout_editor_work.dart';

import '../../operations/presentation/admin_dashboard_page.dart';

import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/core/catalog_search.dart';
import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';

import '../../../core/admin_shell.dart';
import '../../guided_programs/domain/admin_guided_trash.dart';
import 'admin_session_library_status.dart';

class AdminProgramWorkoutsPage extends StatefulWidget {
  const AdminProgramWorkoutsPage({
    super.key,
    required this.program,
    required this.repository,
    this.trashRepository,
    this.workRepository,
  });

  final WorkoutEditorWorkRepository? workRepository;
  final AdminProgram? program;
  final AdminWorkoutRepository repository;
  final AdminGuidedTrashRepository? trashRepository;

  @override
  State<AdminProgramWorkoutsPage> createState() =>
      _AdminProgramWorkoutsPageState();
}

class _AdminProgramWorkoutsPageState extends State<AdminProgramWorkoutsPage> {
  List<AdminWorkoutSummary>? _workouts;
  String? _error;
  String _filter = 'all';
  bool _busy = false;
  final _search = TextEditingController();
  GoRouter? _navigationRouter;
  bool _catalogVisible = false, _refreshScheduled = false;
  int _workRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _navigationRouter) return;
    _navigationRouter?.routerDelegate.removeListener(_routeChanged);
    _navigationRouter = router;
    _catalogVisible = router?.state.uri.path == _routeBase;
    router?.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    final visible = _navigationRouter?.state.uri.path == _routeBase;
    final returned = visible && !_catalogVisible;
    _catalogVisible = visible;
    if (!returned || _refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted || !_catalogVisible) return;
      // Una URL directa no tiene el Future de _create esperando al editor.
      _load();
    });
  }

  @override
  void dispose() {
    _navigationRouter?.routerDelegate.removeListener(_routeChanged);
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
                    ...workout.guidedPrograms.map((p) => p.name),
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
          _workRevision++;
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
    await _load();
    if (saved == true) {
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

  Future<void> _openGuidedProgram(AdminWorkoutProgramUsage program) async {
    await context.push(
      '/guided-programs/${Uri.encodeComponent(program.id)}/edit',
    );
    if (mounted) await _load();
  }

  Future<void> _trash(AdminWorkoutSummary workout) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => EntrenaDialog(
          title: const Text('¿Mover sesión a papelera?'),
          content: Text(
            '«${workout.name}» se conservará y podrás recuperarla desde Sesiones → Papelera. Si está enlazada a programas o calentamientos, o tiene entrenamientos pendientes, primero tendrás que quitar esas referencias.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Cancelar',
              onPrimary: () => Navigator.of(ctx).pop(false),
              secondary: [
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Mover a papelera'),
                ),
              ],
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      await widget.trashRepository!.trashSession(workout.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sesión movida a la papelera.'),
          action: SnackBarAction(label: 'Ver papelera', onPressed: _openTrash),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'No se pudo confirmar la retirada. Actualiza las sesiones antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTrash() async {
    await context.push('/sessions/trash');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(
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
                  ? 'Las sesiones publicadas aparecen en la biblioteca y pueden reutilizarse en programas guiados.'
                  : 'Estas plantillas pertenecen a este programa. Publicarlas no las muestra en la biblioteca general ni las asigna a alumnos.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva sesión'),
                ),
                if (widget.trashRepository != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openTrash,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Papelera'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AdminSessionWorkList(
              limit: 100,
              key: ValueKey(_workRevision),
              repository: widget.workRepository,
              programId: widget.program?.id,
              onOpen: (path) async {
                await context.push(path);
                if (mounted) await _load();
              },
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar sesiones',
                hintText: 'Nombre, programa guiado, carrera o fuerza',
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
                    onTap: _busy ? null : () => _preview(workout),
                    leading: Icon(
                      workout.isRunning
                          ? Icons.directions_run
                          : Icons.fitness_center,
                    ),
                    title: Text(workout.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
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
                          if (widget.program == null) ...[
                            const SizedBox(height: 8),
                            AdminSessionLibraryStatus(session: workout),
                            if (workout.guidedPrograms.isEmpty)
                              const Text('Sin programas guiados asociados')
                            else ...[
                              const Text('Usada en programas guiados:'),
                              for (final program in workout.guidedPrograms)
                                TextButton.icon(
                                  onPressed: () => _openGuidedProgram(program),
                                  icon: const Icon(
                                    Icons.account_tree_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${program.name} · v${program.version} · ${switch (program.status) {
                                      'published' => 'Publicado',
                                      'draft' => 'Borrador',
                                      'archived' => 'Retirado',
                                      _ => program.status,
                                    }}',
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    trailing: widget.trashRepository == null
                        ? const Icon(Icons.chevron_right)
                        : PopupMenuButton<String>(
                            enabled: !_busy,
                            tooltip: 'Más opciones de ${workout.name}',
                            onSelected: (_) => _trash(workout),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'trash',
                                child: Text('Mover a papelera'),
                              ),
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
