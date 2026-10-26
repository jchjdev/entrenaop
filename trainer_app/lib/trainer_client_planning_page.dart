import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/device_training_progress.dart';
import 'package:workout_editor_ui/device_training_progress_tile.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import 'trainer_client_planning_repository.dart';
import 'trainer_assignment_lifecycle_actions.dart';
import 'trainer_client_workspace_repository.dart';
import 'trainer_operations_pages.dart';
import 'trainer_operations_repository.dart';
import 'trainer_program_pages.dart';
import 'trainer_program_repository.dart';
import 'trainer_workout_pages.dart';
import 'trainer_workout_repository.dart';

DateTime _civil(DateTime d, int offset) =>
    DateTime(d.year, d.month, d.day + offset);

class TrainerPlanningEntry {
  TrainerPlanningEntry.own(TrainerClientAgendaItem row)
    : id = row.assignment.id,
      date = row.assignment.date,
      name = row.assignment.name,
      status = row.assignment.status,
      running = row.running,
      origin = 'Tu pauta',
      assignment = row.assignment,
      deviceTraining = row.deviceTraining,
      shared = null;
  TrainerPlanningEntry.shared(SharedCalendarEntry row)
    : id = row.id,
      date = row.date,
      name = row.name,
      status = row.status,
      running = row.running,
      origin = row.source == 'coach'
          ? '${row.trainerName ?? 'Preparador'}${row.own ? ' (tú)' : ''}'
          : row.source == 'user'
          ? 'Plan personal'
          : 'EntrenaOP',
      assignment = null,
      deviceTraining = null,
      shared = row;
  final String id, name, status, origin;
  final DateTime date;
  final bool running;
  final TrainerAssignment? assignment;
  final DeviceTrainingProgress? deviceTraining;
  final SharedCalendarEntry? shared;
  bool get editable =>
      assignment != null &&
      status == 'planned' &&
      assignment!.executionId == null;
  String get statusLabel => switch (status) {
    'planned' => 'Pendiente',
    'completed' => 'Realizada',
    'in_progress' => 'En curso',
    'skipped' => 'Omitida',
    'abandoned' => 'Abandonada',
    'cancelled' => 'Retirada',
    _ => status,
  };
}

/// La misma cita mantiene su ID al reunir la vista propia y la compartida.
/// Solo las lecturas propias proporcionan datos y acciones de la asignación.
List<TrainerPlanningEntry> mergeTrainerPlanningEntries(
  List<TrainerClientAgendaItem> own,
  List<SharedCalendarEntry> shared,
) {
  final entries = <String, TrainerPlanningEntry>{
    for (final row in shared) row.id: TrainerPlanningEntry.shared(row),
    for (final row in own) row.assignment.id: TrainerPlanningEntry.own(row),
  };
  return entries.values.toList()..sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date == 0 ? a.id.compareTo(b.id) : date;
  });
}

typedef _Selection = ({
  TrainerPlanningEntry entry,
  Future<WorkoutTemplate?> recipe,
});

class TrainerClientPlanningPage extends StatefulWidget {
  const TrainerClientPlanningPage({
    super.key,
    required this.clientId,
    required this.workspace,
    required this.access,
    required this.planning,
    required this.sharedCalendar,
    required this.workouts,
    required this.programs,
    required this.operations,
    this.goals,
    this.initialDate,
    this.onCreateSession,
    this.onCreateProgram,
  });
  final String clientId;
  final TrainerClientWorkspaceRepository workspace;
  final TrainerRepository access;
  final TrainerClientPlanningRepository planning;
  final TrainerSharedCalendarRepository sharedCalendar;
  final TrainerWorkoutRepository workouts;
  final TrainerProgramRepository programs;
  final TrainerOperationsRepository operations;
  final Widget? goals;
  final DateTime? initialDate;
  final Future<String?> Function(BuildContext)? onCreateSession,
      onCreateProgram;
  @override
  State<TrainerClientPlanningPage> createState() =>
      _TrainerClientPlanningPageState();
}

class _TrainerClientPlanningPageState extends State<TrainerClientPlanningPage>
    with WidgetsBindingObserver {
  late DateTime _day;
  TrainerClientWorkspace? _client;
  bool _effective = false, _busy = true, _mutation = false, _libraryBusy = true;
  bool _moreOwn = false,
      _moreShared = false,
      _moreLibrary = false,
      _morePrograms = false;
  bool? _sharing;
  String? _error, _sharedError, _libraryError;
  int _generation = 0, _libraryGeneration = 0;
  final _own = <TrainerClientAgendaItem>[], _shared = <SharedCalendarEntry>[];
  List<TrainerWorkout> _library = [];
  List<TrainerProgram> _programs = [];
  final _sessionDrag = Object(), _programDrag = Object();
  final _selection = ValueNotifier<_Selection?>(null);
  bool _programLibrary = false;
  TrainerAssignmentVisibility _visibility = TrainerAssignmentVisibility.current;
  DateTime get _from => _civil(_day, 1 - _day.weekday);
  DateTime get _to => _civil(_from, 6);
  bool get _canAssign =>
      !_busy && !_mutation && _effective && _client?.client.active == true;
  List<TrainerPlanningEntry>
  get _entries => mergeTrainerPlanningEntries(_own, _shared).where((entry) {
    if (entry.assignment != null) return true;
    // La proyección compartida incluye también citas propias: no reintroducir
    // una propia que el filtro de servidor haya excluido o archivado.
    if (entry.shared?.own == true) return false;
    return switch (_visibility) {
      TrainerAssignmentVisibility.current ||
      TrainerAssignmentVisibility.all => true,
      TrainerAssignmentVisibility.withdrawn => entry.status == 'cancelled',
      TrainerAssignmentVisibility.archived => false,
    };
  }).toList();

  @override
  void initState() {
    super.initState();
    _day = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadLibrary();
  }

  @override
  void didUpdateWidget(covariant TrainerClientPlanningPage old) {
    super.didUpdateWidget(old);
    if (old.clientId != widget.clientId) {
      _day = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
      _client = null;
      _effective = false;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_mutation) _load();
  }

  @override
  void dispose() {
    _generation++;
    _libraryGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _selection.dispose();
    super.dispose();
  }

  Future<void> _load({bool moreOwn = false, bool moreShared = false}) async {
    final request = ++_generation;
    final id = widget.clientId, from = _from, to = _to;
    _selection.value = null;
    setState(() {
      _busy = true;
      _error = null;
      _sharedError = null;
      if (!moreOwn && !moreShared) {
        _own.clear();
        _shared.clear();
        _sharing = null;
        _moreOwn = false;
        _moreShared = false;
      }
    });
    try {
      final workspace = await widget.workspace.get(id);
      final access = await widget.access.access();
      if (!mounted || request != _generation) return;
      setState(() {
        _client = workspace;
        _effective = access.effective;
      });
      if (!workspace.client.active || !access.effective) {
        setState(() {
          _shared.clear();
          _sharing = null;
          _moreShared = false;
        });
      }
      if (!moreShared) {
        final page = await widget.planning.week(
          id,
          from,
          to,
          after: moreOwn ? _own.lastOrNull : null,
          visibility: _visibility,
        );
        if (!mounted || request != _generation) return;
        if (page.hasMore && page.items.isEmpty) {
          throw const FormatException(
            'La página de pautas está incompleta. Actualiza la semana.',
          );
        }
        setState(() {
          if (!moreOwn) _own.clear();
          _own.addAll(page.items);
          _moreOwn = page.hasMore;
        });
      }
      if (workspace.client.active && access.effective) {
        try {
          final page = await widget.sharedCalendar.calendar(
            id,
            from,
            to,
            after: moreShared ? _shared.lastOrNull : null,
          );
          if (!mounted || request != _generation) return;
          setState(() {
            if (!moreShared || !page.shared) _shared.clear();
            if (page.shared) _shared.addAll(page.entries);
            _sharing = page.shared;
            _moreShared = page.shared && page.hasMore;
          });
        } catch (error) {
          if (!mounted || request != _generation) return;
          setState(() {
            _shared.clear();
            _sharing = null;
            _moreShared = false;
            _sharedError = trainerError(error);
          });
        }
      }
    } catch (error) {
      if (mounted && request == _generation) {
        setState(() {
          _own.clear();
          _shared.clear();
          _sharing = null;
          _error = trainerError(error);
        });
      }
    } finally {
      if (mounted && request == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _loadLibrary({
    bool sessionsMore = false,
    bool programsMore = false,
  }) async {
    final request = ++_libraryGeneration;
    setState(() {
      _libraryBusy = true;
      _libraryError = null;
    });
    try {
      if (!programsMore) {
        final rows = await widget.workouts.workouts(
          before: sessionsMore ? _library.lastOrNull : null,
        );
        if (!mounted || request != _libraryGeneration) return;
        setState(() {
          _library = sessionsMore ? [..._library, ...rows] : rows;
          _moreLibrary = rows.length == 50;
        });
      }
      if (!sessionsMore) {
        final rows = await widget.programs.programs(
          before: programsMore ? _programs.lastOrNull : null,
        );
        if (!mounted || request != _libraryGeneration) return;
        setState(() {
          _programs = programsMore ? [..._programs, ...rows] : rows;
          _morePrograms = rows.length == 50;
        });
      }
    } catch (error) {
      if (mounted && request == _libraryGeneration) {
        setState(() => _libraryError = trainerError(error));
      }
    } finally {
      if (mounted && request == _libraryGeneration) {
        setState(() => _libraryBusy = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _mutation) return;
    setState(() {
      _mutation = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = trainerError(error));
    } finally {
      if (mounted) setState(() => _mutation = false);
    }
  }

  Future<void> _assignSession(DateTime date, [TrainerWorkout? workout]) async {
    if (!_canAssign) return;
    final relation = _client!.client.activeRelationId!;
    await _run(() async {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => TrainerAssignmentDialog(
          repository: widget.workouts,
          relationId: relation,
          initialWorkout: workout,
          initialDate: date,
        ),
      );
      if (changed == true && mounted) await _load();
    });
  }

  Future<void> _assignProgram(DateTime date, [TrainerProgram? program]) async {
    if (!_canAssign) return;
    final relation = _client!.client.activeRelationId!;
    await _run(() async {
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => TrainerProgramAssignmentDialog(
          repository: widget.programs,
          relationId: relation,
          initialDate: date,
          initialProgram: program?.program,
        ),
      );
      if (changed == true && mounted) await _load();
    });
  }

  Future<void> _create(bool program) async {
    if (!_canAssign) return;
    final day = _day, clientId = widget.clientId;
    final callback = program ? widget.onCreateProgram : widget.onCreateSession;
    if (callback == null) return;
    String? saved;
    await _run(() async {
      saved = await callback(context);
      if (mounted) await _loadLibrary();
    });
    if (!mounted || saved == null || widget.clientId != clientId) return;
    try {
      if (program) {
        final value = await widget.programs.program(saved!);
        if (!mounted || widget.clientId != clientId) return;
        await _assignProgram(
          day,
          _programs.where((p) => p.program.id == saved).firstOrNull ??
              TrainerProgram.fromJson({
                'id': value.id,
                'family_id': value.familyId,
                'version': value.version,
                'status': value.status,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'content': guidedProgramToJson(value),
              }),
        );
      } else {
        final value = await widget.workouts.template(saved!);
        if (!mounted || value == null || widget.clientId != clientId) return;
        await _assignSession(
          day,
          TrainerWorkout.fromJson({
            'id': saved,
            'name': value.name,
            'version': value.version,
            'is_running': value.blocks.any(
              (b) => b.format == WorkoutBlockFormat.running,
            ),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = trainerError(error));
    }
  }

  Future<void> _select(
    TrainerPlanningEntry entry, {
    bool showDialogView = false,
  }) async {
    if (_busy || _mutation) return;
    final request = _generation, id = widget.clientId;
    Future<WorkoutTemplate?> recipe() async {
      final value = entry.assignment != null
          ? await widget.workouts.template(entry.assignment!.templateId)
          : WorkoutTemplateModel.fromJson(
              await widget.sharedCalendar.workout(id, entry.id),
            );
      if (!mounted || request != _generation || id != widget.clientId) {
        throw StateError('La selección ha cambiado.');
      }
      return value;
    }

    _selection.value = (entry: entry, recipe: recipe());
    if (showDialogView && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 850),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(child: _inspector()),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _move(TrainerPlanningEntry entry, DateTime destination) async {
    if (!_canAssign ||
        !entry.editable ||
        !_own.any((row) => row.assignment.id == entry.id)) {
      return;
    }
    await _run(() async {
      await showTrainerMoveDialog(
        context,
        widget.operations,
        entry.assignment!,
        destination,
      );
      if (mounted) await _load();
    });
  }

  Future<void> _movePicker(TrainerPlanningEntry entry) async {
    if (!_canAssign || !entry.editable) return;
    final date = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted && !DateUtils.isSameDay(date, entry.date)) {
      await _move(entry, date);
    }
  }

  Future<void> _cancel(TrainerPlanningEntry entry) async {
    if (!_canAssign ||
        !entry.editable ||
        !_own.any((row) => row.assignment.id == entry.id)) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Retirar pauta pendiente'),
        content: Text(
          'Se cancelará ${entry.name} para ${_client!.client.name}. Se conservará como retirada; después puedes archivarla o borrarla si no tiene datos protegidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Retirar pauta'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(() async {
        await widget.workouts.cancel(entry.id);
        if (mounted) await _load();
      });
    }
  }

  Future<void> _openRoute(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  Future<void> _conversation(TrainerPlanningEntry entry) async {
    if (entry.assignment == null || _busy || _mutation) return;
    await _run(() async {
      final detail = await widget.operations.assignment(entry.id);
      if (detail.clientId != widget.clientId) {
        throw StateError('La pauta no corresponde a este alumno.');
      }
      if (mounted) {
        await context.push(
          '/conversations/${detail.relationId}?assignment=${Uri.encodeComponent(entry.id)}',
        );
      }
    });
  }

  Widget _inspector() => ValueListenableBuilder<_Selection?>(
    valueListenable: _selection,
    builder: (context, selection, _) {
      if (selection == null) {
        return const ProfessionalInspector(
          title: 'Detalle de la selección',
          children: [
            Text(
              'Selecciona una pauta para consultar su receta. Tus resultados, técnica y conversación están en el mismo contexto.',
            ),
          ],
        );
      }
      final entry = selection.entry, own = entry.assignment;
      return ProfessionalInspector(
        title: entry.name,
        subtitle: '${entry.origin} · ${entry.statusLabel}',
        children: [
          Text(
            '${entry.running ? 'Carrera' : 'Fuerza'} · ${trainerDate(entry.date)}',
          ),
          if (own == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Solo lectura. Puedes consultar la pauta para coordinarte.',
              ),
            ),
          if (own != null) ...[
            if (entry.deviceTraining case final progress?)
              DeviceTrainingProgressTile(progress: progress, showName: false),
            if (own.executionId != null) ...[
              FilledButton.icon(
                onPressed: _busy || _mutation
                    ? null
                    : () => _openRoute(
                        '/clients/${widget.clientId}/workouts/${own.id}/result',
                      ),
                icon: const Icon(Icons.insights),
                label: const Text('Ver resultados'),
              ),
              TextButton.icon(
                onPressed: _busy || _mutation
                    ? null
                    : () => _openRoute('/assignments/${own.id}/technique'),
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Vídeos de técnica'),
              ),
            ],
            if (_client?.client.isSelf != true)
              TextButton.icon(
                onPressed: _busy || _mutation
                    ? null
                    : () => _conversation(entry),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Comentar esta pauta'),
              ),
            if (entry.editable) ...[
              FilledButton.icon(
                onPressed: _canAssign
                    ? () => _openRoute('/assignments/${own.id}/adapt')
                    : null,
                icon: const Icon(Icons.tune),
                label: const Text('Adaptar solo esta pauta'),
              ),
              OutlinedButton.icon(
                onPressed: _canAssign ? () => _movePicker(entry) : null,
                icon: const Icon(Icons.event),
                label: const Text('Mover fecha'),
              ),
              TextButton(
                onPressed: _canAssign ? () => _cancel(entry) : null,
                child: const Text('Retirar pauta'),
              ),
            ],
            TrainerAssignmentLifecycleActions(
              key: ValueKey('lifecycle-${own.id}-${own.archiveRevision}'),
              assignment: own,
              repository: widget.workouts,
              enabled: !_busy && !_mutation && _effective,
              onChanged: _load,
              onBusyChanged: (busy) {
                if (mounted) setState(() => _mutation = busy);
              },
            ),
            if (own.note?.isNotEmpty == true) Text(own.note!),
          ],
          const Divider(height: 24),
          FutureBuilder<WorkoutTemplate?>(
            future: selection.recipe,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudo consultar la pauta. ${trainerError(snapshot.error!)}',
                );
              }
              if (snapshot.data == null) {
                return const Text('Receta no disponible.');
              }
              return WorkoutTemplateContent(template: snapshot.data!);
            },
          ),
        ],
      );
    },
  );

  Widget _libraryPane() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Sesiones'),
              selected: !_programLibrary,
              showCheckmark: false,
              onSelected: (_) => setState(() => _programLibrary = false),
            ),
            ChoiceChip(
              label: const Text('Programas'),
              selected: _programLibrary,
              showCheckmark: false,
              onSelected: (_) => setState(() => _programLibrary = true),
            ),
          ],
        ),
      ),
      Expanded(
        child: _programLibrary
            ? ProfessionalLibraryPane<TrainerProgram>(
                title: 'Tus programas',
                items: _programs,
                nameOf: (row) => row.program.name,
                subtitleOf: (row) =>
                    'v${row.program.version} · ${row.program.sessionCount} sesiones',
                dragOwner: _programDrag,
                enabled: _canAssign && !_libraryBusy,
                onSelected: (row) => _assignProgram(_day, row),
                footer: _libraryFooter(program: true),
              )
            : ProfessionalLibraryPane<TrainerWorkout>(
                title: 'Tus sesiones',
                items: _library,
                nameOf: (row) => row.name,
                subtitleOf: (row) =>
                    '${row.isRunning ? 'Carrera' : 'Fuerza'} · v${row.version}',
                dragOwner: _sessionDrag,
                enabled: _canAssign && !_libraryBusy,
                onSelected: (row) => _assignSession(_day, row),
                footer: _libraryFooter(),
              ),
      ),
    ],
  );
  Widget _libraryFooter({bool program = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Arrastra al día o pulsa para pautar en la fecha seleccionada.',
      ),
      if (_libraryBusy) const LinearProgressIndicator(),
      if (_libraryError != null) Text(_libraryError!),
      if (program ? _morePrograms : _moreLibrary)
        TextButton(
          onPressed: _libraryBusy
              ? null
              : () =>
                    _loadLibrary(programsMore: program, sessionsMore: !program),
          child: const Text('Cargar más'),
        ),
      TextButton.icon(
        onPressed:
            _canAssign &&
                (program
                    ? widget.onCreateProgram != null
                    : widget.onCreateSession != null)
            ? () => _create(program)
            : null,
        icon: const Icon(Icons.add),
        label: Text(program ? 'Crear programa aquí' : 'Crear sesión aquí'),
      ),
    ],
  );

  Widget _dropDate(
    DateTime date,
    Widget child,
  ) => DragTarget<ProfessionalLibraryDrag<TrainerWorkout>>(
    onWillAcceptWithDetails: (d) =>
        _canAssign &&
        identical(d.data.owner, _sessionDrag) &&
        _library.any((row) => row.id == d.data.value.id),
    onAcceptWithDetails: (d) {
      if (_canAssign && identical(d.data.owner, _sessionDrag)) {
        _assignSession(date, d.data.value);
      }
    },
    builder: (context, sessions, _) =>
        DragTarget<ProfessionalLibraryDrag<TrainerProgram>>(
          onWillAcceptWithDetails: (d) =>
              _canAssign &&
              identical(d.data.owner, _programDrag) &&
              _programs.any((row) => row.program.id == d.data.value.program.id),
          onAcceptWithDetails: (d) {
            if (_canAssign && identical(d.data.owner, _programDrag)) {
              _assignProgram(date, d.data.value);
            }
          },
          builder: (context, programs, _) => DragTarget<TrainerPlanningEntry>(
            key: ValueKey(
              'client-calendar-drop-${date.year}-${date.month}-${date.day}',
            ),
            onWillAcceptWithDetails: (d) =>
                _canAssign &&
                d.data.editable &&
                _own.any((row) => row.assignment.id == d.data.id) &&
                !DateUtils.isSameDay(date, d.data.date),
            onAcceptWithDetails: (d) => _move(d.data, date),
            builder: (context, entries, _) => DecoratedBox(
              decoration: BoxDecoration(
                color:
                    sessions.isNotEmpty ||
                        programs.isNotEmpty ||
                        entries.isNotEmpty
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            ),
          ),
        ),
  );

  Widget _dayCard(DateTime date, double width, bool inlineInspector) {
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final entries = _entries
        .where((entry) => DateUtils.isSameDay(date, entry.date))
        .toList();
    return SizedBox(
      width: width,
      child: _dropDate(
        date,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: _busy || _mutation
                      ? null
                      : () => setState(() => _day = date),
                  child: Text(
                    '${weekdays[date.weekday - 1]} ${date.day}/${date.month}',
                    style: TextStyle(
                      fontWeight: DateUtils.isSameDay(_day, date)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (entries
                        .where((entry) => entry.status != 'cancelled')
                        .length >
                    1)
                  const Text(
                    'Varias pautas: revisa la carga',
                    style: TextStyle(fontSize: 12),
                  ),
                for (final entry in entries) _entryCard(entry, inlineInspector),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Sin pautas visibles',
                      textAlign: TextAlign.center,
                    ),
                  ),
                IconButton(
                  tooltip: 'Pautar el ${trainerDate(date)}',
                  onPressed: _canAssign
                      ? () {
                          setState(() => _day = date);
                          _assignSession(date);
                        }
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryCard(TrainerPlanningEntry entry, bool inlineInspector) {
    final color = entry.running
        ? const Color(0xffff9c68)
        : const Color(0xff82b1ff);
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('client-planning-entry-${entry.id}'),
        onTap: _busy || _mutation
            ? null
            : () {
                setState(() => _day = entry.date);
                _select(entry, showDialogView: !inlineInspector);
              },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.running ? Icons.directions_run : Icons.fitness_center,
                color: color,
                size: 18,
              ),
              Text(entry.name, style: Theme.of(context).textTheme.labelLarge),
              Text(entry.origin, style: Theme.of(context).textTheme.bodySmall),
              Text(
                entry.assignment?.archived == true
                    ? 'Archivada · ${entry.statusLabel}'
                    : entry.statusLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (entry.assignment == null)
                const Icon(Icons.visibility_outlined, size: 14),
            ],
          ),
        ),
      ),
    );
    if (!_canAssign || !entry.editable) return card;
    return Draggable<TrainerPlanningEntry>(
      data: entry,
      feedback: Material(
        elevation: 8,
        child: SizedBox(
          width: 200,
          child: ListTile(
            title: Text(entry.name),
            subtitle: const Text('Revisar movimiento antes de aplicar'),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Widget _calendar(bool inlineInspector) => ListView(
    key: const ValueKey('client-calendar-scroll'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        _client?.client.name ?? 'Planificación del alumno',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (_client?.client.isSelf == true)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Lo que te pautes aquí aparecerá en la agenda de tu app de deportista. '
            'Puedes realizarlo con esta misma cuenta y consultar aquí sus resultados. No ocupa plaza.',
          ),
        ),
      if (widget.goals != null) widget.goals!,
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: _busy || _mutation
                ? null
                : () {
                    setState(() => _day = _civil(_day, -7));
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${trainerDate(_from)} – ${trainerDate(_to)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: _busy || _mutation
                ? null
                : () {
                    setState(() => _day = _civil(_day, 7));
                    _load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: _busy || _mutation
                ? null
                : () {
                    setState(() => _day = DateUtils.dateOnly(DateTime.now()));
                    _load();
                  },
            child: const Text('Hoy'),
          ),
        ],
      ),
      TrainerAssignmentVisibilityFilter(
        value: _visibility,
        onChanged: _busy || _mutation
            ? null
            : (value) {
                setState(() => _visibility = value);
                _load();
              },
      ),
      const SizedBox(height: 12),
      Text('Fecha seleccionada: ${trainerDate(_day)}'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _canAssign ? () => _assignSession(_day) : null,
            icon: const Icon(Icons.add),
            label: const Text('Asignar sesión'),
          ),
          OutlinedButton.icon(
            onPressed: _canAssign ? () => _assignProgram(_day) : null,
            icon: const Icon(Icons.view_week_outlined),
            label: const Text('Pautar programa'),
          ),
          TextButton(
            onPressed: _canAssign && widget.onCreateSession != null
                ? () => _create(false)
                : null,
            child: const Text('Crear sesión'),
          ),
          TextButton(
            onPressed: _canAssign && widget.onCreateProgram != null
                ? () => _create(true)
                : null,
            child: const Text('Crear programa'),
          ),
        ],
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_client?.client.active == false)
        const Text(
          'Servicio inactivo: conservas tus pautas y resultados. No puedes crear nuevas asignaciones.',
        ),
      if (_sharing == false)
        const Text(
          'Ves tus propias pautas. Para coordinaros, el alumno puede compartir su calendario desde Preparador → Vínculos.',
        ),
      if (_sharedError != null)
        Text(
          'No se pudo comprobar el calendario compartido. Solo se muestran tus pautas. $_sharedError',
        ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Carrera y fuerza · autor y estado en cada tarjeta · pautas ajenas en solo lectura',
        ),
      ),
      if (_moreOwn || _moreShared)
        const Text(
          'Semana parcial: carga el resto antes de valorar su planificación completa.',
        ),
      LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth >= 1100
              ? 7
              : c.maxWidth >= 600
              ? 3
              : c.maxWidth >= 400
              ? 2
              : 1;
          final width = (c.maxWidth - (count - 1) * 8) / count;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 7; i++)
                _dayCard(_civil(_from, i), width, inlineInspector),
            ],
          );
        },
      ),
      if (_moreOwn)
        TextButton(
          onPressed: _busy ? null : () => _load(moreOwn: true),
          child: const Text('Cargar más pautas propias de la semana'),
        ),
      if (_moreShared)
        TextButton(
          onPressed: _busy ? null : () => _load(moreShared: true),
          child: const Text('Cargar más calendario compartido'),
        ),
      const SizedBox(height: 24),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Planificación del alumno'),
      actions: [
        IconButton(
          tooltip: 'Actualizar planificación',
          onPressed: _busy || _mutation ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, c) {
        final inspector = ProfessionalEditorWorkspace.hasInspector(context, c);
        return ProfessionalEditorWorkspace(
          library: _libraryPane(),
          inspector: _inspector(),
          child: _calendar(inspector),
        );
      },
    ),
  );
}
