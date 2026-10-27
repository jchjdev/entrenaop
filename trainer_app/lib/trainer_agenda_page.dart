import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';
import 'trainer_workout_pages.dart';
import 'trainer_agenda_client_picker.dart';
import 'trainer_month_calendar.dart';
import 'trainer_pointer_drag.dart';
import 'trainer_assignment_lifecycle_actions.dart';

import 'package:workout_core/professional_assessment.dart';

String agendaDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TrainerAgendaItem {
  TrainerAgendaItem.fromJson(Map<String, dynamic> row)
    : assignment = TrainerAssignment.fromJson(row),
      clientId = row['client_id'] as String,
      clientName = row['client_name'] as String;
  final TrainerAssignment assignment;
  final String clientId, clientName;
}

abstract class TrainerAgendaRepository {
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  });
}

class SupabaseTrainerAgendaRepository implements TrainerAgendaRepository {
  const SupabaseTrainerAgendaRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    _identity();
    final rows = await authenticatedTrainerRpc(
      client,
      userId,
      'list_trainer_agenda_filtered',
      params: {
        'p_visibility': visibility.name,
        'p_expected_owner': userId,
        'p_from': agendaDate(from),
        'p_to': agendaDate(to),
        'p_after_date': after == null
            ? null
            : agendaDate(after.assignment.date),
        'p_after_id': after?.assignment.id,
      },
    );
    _identity();
    return (rows as List)
        .map(
          (row) =>
              TrainerAgendaItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }
}

enum _AgendaView { month, week, day, list }

enum _AgendaEntryAction { planning, result, move, adapt, withdraw }

class TrainerAgendaPage extends StatefulWidget {
  const TrainerAgendaPage({
    super.key,
    required this.repository,
    this.now,
    this.onMove,
    this.onCopyWeek,
    this.onAdapt,
    this.assessments,
    this.workouts,
    this.access,
  });
  final TrainerAgendaRepository repository;
  final TrainerWorkoutRepository? workouts;
  final TrainerRepository? access;
  final ProfessionalAssessmentEventRepository? assessments;
  final DateTime? now;
  final Future<void> Function(TrainerAssignment assignment, DateTime date)?
  onMove;
  final Future<void> Function(DateTime weekStart, int offsetDays)? onCopyWeek;
  final Future<void> Function(TrainerAssignment assignment)? onAdapt;

  @override
  State<TrainerAgendaPage> createState() => _TrainerAgendaPageState();
}

class _TrainerAgendaPageState extends State<TrainerAgendaPage> {
  late DateTime _anchor = DateUtils.dateOnly(widget.now ?? DateTime.now());
  DateTime? _selected;
  _AgendaView _view = _AgendaView.month;
  List<TrainerAgendaItem> _items = [];
  List<ProfessionalAssessmentEvent> _assessments = [];
  bool _assessmentsBusy = false, _moreAssessments = false;
  String? _assessmentError;
  final _clientNames = <String, String>{};
  String? _clientFilter, _statusFilter, _error;
  TrainerAssignmentVisibility _visibility = TrainerAssignmentVisibility.current;
  bool _busy = true, _more = false, _mutating = false;
  int _request = 0;
  final _libraryOwner = Object();
  List<TrainerWorkout> _library = [];
  bool _libraryBusy = false, _libraryMore = false;
  String? _libraryError;

  bool get _locked => _busy || _mutating || _assessmentsBusy;
  DateTime _civilOffset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
  DateTime _weekStart(DateTime date) => _civilOffset(date, 1 - date.weekday);
  DateTime get _from => switch (_view) {
    _AgendaView.month ||
    _AgendaView.list => DateTime(_anchor.year, _anchor.month),
    _AgendaView.week => _weekStart(_anchor),
    _AgendaView.day => _anchor,
  };
  DateTime get _to => switch (_view) {
    _AgendaView.month ||
    _AgendaView.list => DateTime(_anchor.year, _anchor.month + 1, 0),
    _AgendaView.week => _civilOffset(_from, 6),
    _AgendaView.day => _anchor,
  };

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.workouts != null) _loadLibrary();
  }

  Future<void> _loadLibrary({bool more = false}) async {
    if (_libraryBusy || widget.workouts == null) return;
    setState(() {
      _libraryBusy = true;
      _libraryError = null;
    });
    try {
      final rows = await widget.workouts!.workouts(
        before: more ? _library.last : null,
      );
      if (mounted) {
        setState(() {
          _library = more ? [..._library, ...rows] : rows;
          _libraryMore = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _libraryError = trainerError(e));
    } finally {
      if (mounted) setState(() => _libraryBusy = false);
    }
  }

  Widget _libraryPane() => ProfessionalLibraryPane<TrainerWorkout>(
    title: 'Sesiones para asignar',
    items: _library,
    nameOf: (s) => s.name,
    subtitleOf: (s) =>
        '${s.isRunning ? 'Carrera' : 'Fuerza'} · v${s.version} · Privada',
    dragOwner: _libraryOwner,
    enabled: !_locked && !_libraryBusy && widget.access != null,
    onSelected: (workout) => _assignFromLibrary(workout, _selected ?? _anchor),
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Arrastra a un día. Revisa alumno, fecha y receta antes de confirmar.',
        ),
        if (_libraryBusy) const LinearProgressIndicator(),
        if (_libraryError != null) Text(_libraryError!),
        TextButton(
          onPressed: _libraryBusy ? null : _loadLibrary,
          child: const Text('Actualizar biblioteca'),
        ),
        if (_libraryMore)
          TextButton(
            onPressed: _libraryBusy ? null : () => _loadLibrary(more: true),
            child: const Text('Cargar más sesiones'),
          ),
      ],
    ),
  );

  Future<void> _assignFromLibrary(TrainerWorkout workout, DateTime date) async {
    if (_locked ||
        widget.access == null ||
        widget.workouts == null ||
        !_library.any((s) => s.id == workout.id)) {
      return;
    }
    await _mutation(() async {
      final client = await showDialog<TrainerClient>(
        context: context,
        builder: (_) => TrainerAgendaClientPicker(
          repository: widget.access!,
          selectedId: _clientFilter,
        ),
      );
      if (!mounted || client?.activeRelationId == null) return;
      await showDialog<bool>(
        context: context,
        builder: (_) => TrainerAssignmentDialog(
          repository: widget.workouts!,
          relationId: client!.activeRelationId!,
          initialWorkout: workout,
          initialDate: date,
        ),
      );
    });
  }

  bool _canMoveRow(TrainerAgendaItem row, DateTime date) =>
      !_locked &&
      widget.onMove != null &&
      _editable(row.assignment) &&
      !DateUtils.isSameDay(row.assignment.date, date) &&
      _items.any((current) => identical(current, row));

  Widget _dateDrop(
    DateTime date,
    Widget child, {
    String keyPrefix = 'agenda-board-drop',
  }) => DragTarget<TrainerAgendaItem>(
    key: ValueKey('$keyPrefix-${agendaDate(date)}'),
    onWillAcceptWithDetails: (d) => _canMoveRow(d.data, date),
    onAcceptWithDetails: (d) {
      if (_canMoveRow(d.data, date)) _proposeMove(d.data.assignment, date);
    },
    builder: (context, rows, rejected) =>
        DragTarget<ProfessionalLibraryDrag<TrainerWorkout>>(
          onWillAcceptWithDetails: (d) =>
              !_locked &&
              identical(d.data.owner, _libraryOwner) &&
              widget.access != null &&
              widget.workouts != null,
          onAcceptWithDetails: (d) {
            if (identical(d.data.owner, _libraryOwner)) {
              _assignFromLibrary(d.data.value, date);
            }
          },
          builder: (context, recipes, rejected) => DecoratedBox(
            decoration: BoxDecoration(
              color: rows.isNotEmpty || recipes.isNotEmpty
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
  );

  Widget _weekBoard(List<TrainerAgendaItem> rows) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth / 7).clamp(
        148.0 * MediaQuery.textScalerOf(context).scale(13) / 13,
        double.infinity,
      );
      return SizedBox(
        height: 570,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var day = 0; day < 7; day++)
                SizedBox(
                  width: width,
                  child: _dateDrop(
                    _civilOffset(_from, day),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton(
                              onPressed: _locked
                                  ? null
                                  : () => setState(
                                      () =>
                                          _selected = _civilOffset(_from, day),
                                    ),
                              child: Text(
                                '${['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][day]} ${_civilOffset(_from, day).day}',
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView(
                                children: [
                                  for (final row in rows.where(
                                    (r) => DateUtils.isSameDay(
                                      r.assignment.date,
                                      _civilOffset(_from, day),
                                    ),
                                  ))
                                    _boardCard(row),
                                  for (final event
                                      in _assessments
                                          .where(_matchesAssessment)
                                          .where(
                                            (e) =>
                                                e.status != 'withdrawn' &&
                                                DateUtils.isSameDay(
                                                  e.date,
                                                  _civilOffset(_from, day),
                                                ),
                                          ))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 4,
                                      ),
                                      child: TrainerCalendarEntryTile(
                                        entry: _calendarAssessment(event),
                                      ),
                                    ),
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'Soltar aquí',
                                      textAlign: TextAlign.center,
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
                ),
            ],
          ),
        ),
      );
    },
  );

  TrainerCalendarEntry _calendarEntry(TrainerAgendaItem row) {
    final assignment = row.assignment;
    return TrainerCalendarEntry(
      id: 'session-${assignment.id}',
      date: assignment.date,
      personId: row.clientId,
      personName: row.clientName,
      title: assignment.name,
      stateLabel:
          '${assignment.archived ? 'Archivada · ' : ''}${assignment.statusLabel} · Versión ${assignment.version}',
      muted: assignment.archived || assignment.status == 'cancelled',
      completed: assignment.status == 'completed',
      onTap: _locked ? null : () => _showCalendarEntry(row),
      dragBuilder: _editable(assignment) && widget.onMove != null && !_locked
          ? (child) => _dragCalendarEntry(row, child, 'agenda-month-drag')
          : null,
    );
  }

  Widget _dragCalendarEntry(
    TrainerAgendaItem row,
    Widget child,
    String keyPrefix,
  ) {
    final feedback = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('${row.clientName}\n${row.assignment.name}'),
        ),
      ),
    );
    return TrainerPointerDrag<TrainerAgendaItem>(
      key: ValueKey('$keyPrefix-${row.assignment.id}'),
      data: row,
      feedback: feedback,
      child: child,
    );
  }

  Widget _boardCard(TrainerAgendaItem row) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: TrainerCalendarEntryTile(entry: _calendarEntry(row)),
    );
    return _editable(row.assignment) && widget.onMove != null && !_locked
        ? _dragCalendarEntry(row, child, 'agenda-board-drag')
        : child;
  }

  Future<void> _showCalendarEntry(TrainerAgendaItem row) async {
    if (_locked) return;
    final assignment = row.assignment;
    final action = await showDialog<_AgendaEntryAction>(
      context: context,
      builder: (dialogContext) => EntrenaDialog(
        title: Text(assignment.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row.clientName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${_dayLabel(assignment.date)} · ${assignment.statusLabel} · Versión ${assignment.version}',
            ),
            if (assignment.archived) const Text('Asignación archivada'),
            if (assignment.note?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(assignment.note!),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _AgendaEntryAction.planning),
              icon: const Icon(Icons.person_outline),
              label: const Text('Planificación del alumno'),
            ),
            if (assignment.executionId != null)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _AgendaEntryAction.result),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Ver resultados'),
              ),
            if (_editable(assignment) && widget.onMove != null)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _AgendaEntryAction.move),
                icon: const Icon(Icons.event_outlined),
                label: const Text('Mover fecha'),
              ),
            if (_editable(assignment) && widget.workouts != null)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _AgendaEntryAction.withdraw),
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Retirar sesión'),
              ),
            if (_editable(assignment) && widget.onAdapt != null)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _AgendaEntryAction.adapt),
                icon: const Icon(Icons.tune),
                label: const Text('Adaptar pauta'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (!mounted || _locked) return;
    switch (action) {
      case _AgendaEntryAction.planning:
        context.push('/clients/${row.clientId}/workouts');
      case _AgendaEntryAction.result:
        context.push(
          '/clients/${row.clientId}/workouts/${assignment.id}/result',
        );
      case _AgendaEntryAction.move:
        await _proposeMove(assignment);
      case _AgendaEntryAction.withdraw:
        await _withdraw(row);
      case _AgendaEntryAction.adapt:
        if (_editable(assignment) && widget.onAdapt != null) {
          await _mutation(() => widget.onAdapt!(assignment));
        }
      case null:
        break;
    }
  }

  Future<void> _withdraw(TrainerAgendaItem row) async {
    if (_locked || !_editable(row.assignment) || widget.workouts == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Retirar esta sesión?'),
        content: Text(
          'Se retirará ${row.assignment.name} de ${row.clientName}. Se conservará en Retiradas; después podrás archivarla o borrarla si no tiene datos protegidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Retirar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && !_locked) {
      await _mutation(() => widget.workouts!.cancel(row.assignment.id));
    }
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    final from = _from, to = _to;
    final assessmentFetch = !more
        ? _loadAssessments(request: request)
        : Future<void>.value();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.range(
        from,
        to,
        after: more && _items.isNotEmpty ? _items.last : null,
        visibility: _visibility,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = more ? [..._items, ...rows] : rows;
        for (final row in rows) {
          _clientNames[row.clientId] = row.clientName;
        }
        _more = rows.length == 100;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      await assessmentFetch;
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _loadAssessments({bool more = false, int? request}) async {
    final repository = widget.assessments;
    if (repository == null) return;
    final generation = request ?? _request;
    final from = _from, end = _civilOffset(_to, 1);
    setState(() {
      _assessmentsBusy = true;
      _assessmentError = null;
    });
    try {
      final rows = await repository.listAssessmentEvents(
        start: from,
        endExclusive: end,
        before: more && _assessments.isNotEmpty ? _assessments.last : null,
      );
      if (!mounted || generation != _request) return;
      setState(() {
        _assessments = more ? [..._assessments, ...rows] : rows;
        _moreAssessments = rows.length == ProfessionalAssessmentEvent.pageSize;
        for (final row in rows) {
          _clientNames[row.clientId] = row.personName;
        }
      });
    } catch (error) {
      if (mounted && generation == _request) {
        setState(() {
          _assessmentError = trainerError(error);
          if (!more) _assessments = [];
        });
      }
    } finally {
      if (mounted && generation == _request) {
        setState(() => _assessmentsBusy = false);
      }
    }
  }

  bool _matchesAssessment(ProfessionalAssessmentEvent event) =>
      _visibility != TrainerAssignmentVisibility.archived &&
      _visibility != TrainerAssignmentVisibility.withdrawn &&
      (_clientFilter == null || _clientFilter == event.clientId) &&
      (_statusFilter == null ||
          _statusFilter ==
              (event.status == 'withdrawn' ? 'cancelled' : event.status));

  void _navigate(int offset) {
    setState(() {
      _anchor = switch (_view) {
        _AgendaView.month ||
        _AgendaView.list => DateTime(_anchor.year, _anchor.month + offset),
        _AgendaView.week => _civilOffset(_anchor, 7 * offset),
        _AgendaView.day => _civilOffset(_anchor, offset),
      };
      _selected = null;
      _items = [];
    });
    _load();
  }

  void _changeView(_AgendaView view) {
    if (_view == view) return;
    setState(() {
      _view = view;
      if (_selected != null) _anchor = _selected!;
      _selected = null;
      _items = [];
    });
    _load();
  }

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  String _dayLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String get _periodLabel => switch (_view) {
    _AgendaView.month ||
    _AgendaView.list => '${_months[_anchor.month - 1]} ${_anchor.year}',
    _AgendaView.week => '${_dayLabel(_from)} – ${_dayLabel(_to)}',
    _AgendaView.day => _dayLabel(_anchor),
  };
  String get _unitLabel => switch (_view) {
    _AgendaView.month || _AgendaView.list => 'Mes',
    _AgendaView.week => 'Semana',
    _AgendaView.day => 'Día',
  };
  bool _matches(TrainerAgendaItem item) =>
      (_clientFilter == null || item.clientId == _clientFilter) &&
      (_statusFilter == null || item.assignment.status == _statusFilter);
  bool _editable(TrainerAssignment assignment) =>
      assignment.status == 'planned' && assignment.executionId == null;

  Future<void> _mutation(Future<void> Function() operation) async {
    if (_locked) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        final message = trainerError(e);
        setState(() => _error = message);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<DateTime?> _chooseDate({
    required String title,
    required DateTime initial,
    required String action,
    bool mondayOnly = false,
  }) async {
    final controller = TextEditingController(text: agendaDate(initial));
    String? error;
    var closing = false;
    try {
      return await showDialog<DateTime>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(title),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mondayOnly)
                  const Text(
                    'Se copiará la semana completa de todos tus alumnos, aunque haya filtros. El servidor volverá a validar todas las pautas de esa semana, no solo las cargadas. Las originales se conservan.',
                  ),
                if (!mondayOnly)
                  const Text(
                    'Esta fecha propone el cambio. La confirmación y las coincidencias se revisarán antes de guardarlo.',
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('agenda-date-input'),
                  controller: controller,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: mondayOnly
                        ? 'Lunes de la semana destino'
                        : 'Fecha destino',
                    hintText: 'AAAA-MM-DD',
                    errorText: error,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2200, 12, 31),
                    );
                    if (picked != null && context.mounted) {
                      update(() {
                        controller.text = agendaDate(picked);
                        error = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Elegir en calendario'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (closing) return;
                  final text = controller.text.trim();
                  final parsed = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
                      ? DateTime.tryParse(text)
                      : null;
                  if (parsed == null ||
                      agendaDate(parsed) != text ||
                      parsed.year < 1970 ||
                      parsed.year > 2200) {
                    update(
                      () => error = 'Introduce una fecha válida: AAAA-MM-DD.',
                    );
                  } else if (mondayOnly && parsed.weekday != DateTime.monday) {
                    update(
                      () => error =
                          'Elige un lunes para mantener los días de la semana.',
                    );
                  } else {
                    closing = true;
                    Navigator.pop(dialogContext, DateUtils.dateOnly(parsed));
                  }
                },
                child: Text(action),
              ),
            ],
          ),
        ),
      );
    } finally {
      // El diálogo puede terminar su animación después de resolver el Future.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }

  Future<void> _proposeMove(
    TrainerAssignment assignment, [
    DateTime? date,
  ]) async {
    if (_locked || !_editable(assignment) || widget.onMove == null) return;
    final target =
        date ??
        await _chooseDate(
          title: 'Mover pauta',
          initial: assignment.date,
          action: 'Proponer movimiento',
        );
    if (!mounted ||
        target == null ||
        DateUtils.isSameDay(target, assignment.date)) {
      return;
    }
    await _mutation(() => widget.onMove!(assignment, target));
  }

  Future<void> _copyWeek() async {
    if (_locked || widget.onCopyWeek == null) return;
    final source = _weekStart(_selected ?? _anchor);
    final target = await _chooseDate(
      title: 'Copiar semana del ${_dayLabel(source)}',
      initial: _civilOffset(source, 7),
      action: 'Revisar copia de semana',
      mondayOnly: true,
    );
    if (!mounted || target == null) return;
    // UTC solo calcula la diferencia entre componentes civiles, sin desplazar
    // fechas por los cambios de horario de verano del equipo.
    final offset = DateTime.utc(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime.utc(source.year, source.month, source.day)).inDays;
    if (offset == 0) {
      setState(() => _error = 'Elige una semana destino diferente.');
      return;
    }
    await _mutation(() => widget.onCopyWeek!(source, offset));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where(_matches).toList();
    final assessmentEvents = _assessments
        .where(_matchesAssessment)
        .where(
          (e) => _selected == null || DateUtils.isSameDay(e.date, _selected),
        )
        .toList();
    final visible = _selected == null
        ? filtered
        : filtered
              .where((i) => DateUtils.isSameDay(i.assignment.date, _selected))
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda profesional'),
        actions: [
          IconButton(
            onPressed: _locked ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ProfessionalEditorWorkspace(
        library: _libraryPane(),
        child: Center(
          child: ConstrainedBox(
            constraints: ProfessionalWorkspaceScope.pageConstraints(
              context,
              maxWidth: 1050,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Planificación y resultados de tus alumnos. Aquí se muestran las pautas de tu servicio; cada alumno conserva también su agenda personal.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in {
                      _AgendaView.month: 'Mes',
                      _AgendaView.week: 'Semana',
                      _AgendaView.day: 'Día',
                      _AgendaView.list: 'Lista',
                    }.entries)
                      ChoiceChip(
                        key: ValueKey('agenda-view-${entry.key.name}'),
                        label: Text(entry.value),
                        selected: _view == entry.key,
                        onSelected: _locked
                            ? null
                            : (_) => _changeView(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _locked ? null : () => _navigate(-1),
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '$_unitLabel anterior',
                    ),
                    Text(
                      _periodLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: _locked ? null : () => _navigate(1),
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '$_unitLabel siguiente',
                    ),
                    TextButton(
                      onPressed: _locked
                          ? null
                          : () {
                              final today = DateUtils.dateOnly(
                                widget.now ?? DateTime.now(),
                              );
                              setState(() {
                                _anchor = today;
                                _selected = _view == _AgendaView.day
                                    ? null
                                    : today;
                                _items = [];
                              });
                              _load();
                            },
                      child: const Text('Hoy'),
                    ),
                    if (_selected != null)
                      TextButton(
                        onPressed: () => setState(() => _selected = null),
                        child: Text(
                          _view == _AgendaView.week
                              ? 'Ver toda la semana'
                              : 'Ver todo el mes',
                        ),
                      ),
                    if (widget.onCopyWeek != null)
                      OutlinedButton.icon(
                        onPressed: _locked ? null : _copyWeek,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar semana'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 650
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('agenda-client-filter'),
                            initialValue: _clientFilter ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Alumno',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Todos los alumnos'),
                              ),
                              for (final entry in _clientNames.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _locked
                                ? null
                                : (value) => setState(
                                    () => _clientFilter = value == ''
                                        ? null
                                        : value,
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('agenda-status-filter'),
                            initialValue: _statusFilter ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: [
                              for (final entry in {
                                '': 'Todos los estados',
                                'planned': 'Pendiente',
                                'in_progress': 'En curso',
                                'completed': 'Completada',
                                'skipped': 'Omitida',
                                'abandoned': 'Abandonada',
                                'cancelled': 'Retirada',
                              }.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _locked
                                ? null
                                : (value) => setState(
                                    () => _statusFilter = value == ''
                                        ? null
                                        : value,
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                TrainerAssignmentVisibilityFilter(
                  value: _visibility,
                  onChanged: _locked
                      ? null
                      : (value) {
                          setState(() {
                            _visibility = value;
                            _items = [];
                            _statusFilter = null;
                          });
                          _load();
                        },
                ),
                const SizedBox(height: 12),
                if (_locked) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _locked ? null : _load,
                    child: const Text('Reintentar'),
                  ),
                ],
                if (_more)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Hay más pautas por cargar. Los recuentos del calendario son parciales. Los filtros solo incluyen las pautas cargadas.',
                    ),
                  ),
                const SizedBox(height: 12),
                if (_view == _AgendaView.week &&
                    ProfessionalWorkspaceScope.isDesktop(context))
                  _weekBoard(filtered)
                else if (_view == _AgendaView.month ||
                    _view == _AgendaView.week)
                  _grid(filtered),
                const SizedBox(height: 16),
                Text(
                  _selected != null
                      ? 'Pautas del ${_selected!.day}/${_selected!.month}'
                      : switch (_view) {
                          _AgendaView.month ||
                          _AgendaView.list => 'Pautas del mes',
                          _AgendaView.week => 'Pautas de la semana',
                          _AgendaView.day => 'Pautas del día',
                        },
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!_busy && visible.isEmpty && _error == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _more
                          ? 'No hay pautas en esta selección entre las cargadas.'
                          : 'No hay pautas en esta selección.',
                    ),
                  ),
                ProfessionalCatalogGrid(
                  minCardWidth: 340,
                  children: [for (final row in visible) _card(row)],
                ),
                if (widget.assessments != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Pruebas y simulacros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_assessmentError != null) ...[
                    Text(
                      'No se pudieron cargar las pruebas. Las sesiones se muestran por separado.',
                    ),
                    TextButton(
                      onPressed: _locked ? null : () => _loadAssessments(),
                      child: const Text('Reintentar pruebas'),
                    ),
                  ],
                  if (!_assessmentsBusy &&
                      _assessmentError == null &&
                      assessmentEvents.isEmpty)
                    Text(
                      _moreAssessments
                          ? 'No hay pruebas en esta selección entre las cargadas.'
                          : 'No hay pruebas en esta selección.',
                    ),
                  for (final event in assessmentEvents)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: Text('${event.personName} · ${event.title}'),
                        subtitle: Text(
                          '${_dayLabel(event.date)} · ${switch (event.status) {
                            'planned' => 'Pendiente',
                            'in_progress' => 'En curso',
                            'completed' => 'Completada',
                            'withdrawn' => 'Retirada',
                            _ => 'Estado desconocido',
                          }}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _locked
                            ? null
                            : () async {
                                await context.push(
                                  '/clients/${event.clientId}/assessments/${event.id}',
                                );
                                if (mounted) await _load();
                              },
                      ),
                    ),
                  if (_moreAssessments) ...[
                    const Text(
                      'Hay más pruebas por cargar; su recuento es parcial y los filtros solo incluyen las cargadas.',
                    ),
                    OutlinedButton(
                      onPressed: _locked
                          ? null
                          : () => _loadAssessments(more: true),
                      child: const Text('Cargar más pruebas del periodo'),
                    ),
                  ],
                ],

                if (_more)
                  OutlinedButton(
                    onPressed: _locked ? null : () => _load(more: true),
                    child: Text(
                      _view == _AgendaView.month || _view == _AgendaView.list
                          ? 'Cargar más pautas del mes'
                          : 'Cargar más pautas del periodo',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(TrainerAgendaItem row) {
    final assignment = row.assignment;
    final card = Card(
      key: ValueKey('agenda-assignment-${assignment.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row.clientName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(assignment.name),
            Text(
              '${assignment.date.day}/${assignment.date.month} · ${assignment.statusLabel} · v${assignment.version}',
            ),
            if (assignment.note?.isNotEmpty == true) Text(assignment.note!),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _locked
                      ? null
                      : () => context.go('/clients/${row.clientId}/workouts'),
                  child: const Text('Planificación del alumno'),
                ),
                if (assignment.executionId != null)
                  FilledButton.tonal(
                    onPressed: _locked
                        ? null
                        : () => context.push(
                            '/clients/${row.clientId}/workouts/${assignment.id}/result',
                          ),
                    child: const Text('Ver resultados'),
                  ),
                if (_editable(assignment) && widget.onMove != null)
                  TextButton.icon(
                    key: ValueKey('agenda-move-${assignment.id}'),
                    onPressed: _locked ? null : () => _proposeMove(assignment),
                    icon: const Icon(Icons.event),
                    label: const Text('Mover fecha'),
                  ),
                if (_editable(assignment) && widget.workouts != null)
                  TextButton.icon(
                    key: ValueKey('agenda-withdraw-${assignment.id}'),
                    onPressed: _locked ? null : () => _withdraw(row),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Retirar sesión'),
                  ),
                if (_editable(assignment) && widget.onAdapt != null)
                  TextButton.icon(
                    key: ValueKey('agenda-adapt-${assignment.id}'),
                    onPressed: _locked
                        ? null
                        : () => _mutation(() => widget.onAdapt!(assignment)),
                    icon: const Icon(Icons.tune),
                    label: const Text('Adaptar pauta'),
                  ),
              ],
            ),
            if (widget.workouts != null)
              TrainerAssignmentLifecycleActions(
                key: ValueKey(
                  'lifecycle-${assignment.id}-${assignment.archiveRevision}',
                ),
                assignment: assignment,
                repository: widget.workouts!,
                enabled: !_locked,
                onChanged: _load,
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _mutating = busy);
                },
              ),
            if (_editable(assignment) &&
                widget.onMove != null &&
                (_view == _AgendaView.month || _view == _AgendaView.week))
              const Text(
                'También puedes mantener pulsada la tarjeta y arrastrarla a un día del calendario.',
              ),
          ],
        ),
      ),
    );
    if (!_editable(assignment) || widget.onMove == null || _locked) return card;
    return _dragCalendarEntry(row, card, 'agenda-drag');
  }

  TrainerCalendarEntry _calendarAssessment(ProfessionalAssessmentEvent event) =>
      TrainerCalendarEntry(
        id: 'assessment-${event.id}',
        date: event.date,
        personId: event.clientId,
        personName: event.personName,
        title: event.title,
        stateLabel: switch (event.status) {
          'planned' => 'Pendiente',
          'completed' => 'Completada',
          _ => event.status,
        },
        assessment: true,
        completed: event.status == 'completed',
        onTap: _locked
            ? null
            : () => context.push(
                '/clients/${event.clientId}/assessments/${event.id}',
              ),
      );

  Widget _grid(List<TrainerAgendaItem> filtered) => TrainerMonthCalendar(
    anchor: _anchor,
    today: DateUtils.dateOnly(widget.now ?? DateTime.now()),
    selected: _selected ?? (_view == _AgendaView.week ? _anchor : null),
    week: _view == _AgendaView.week,
    enabled: !_locked,
    partial: _more || _moreAssessments,
    onSelectDate: (date) => setState(() => _selected = date),
    onSelectAdjacentDate: (date) {
      setState(() {
        _anchor = date;
        _selected = date;
        _items = [];
        _assessments = [];
      });
      _load();
    },
    dropTargetBuilder: (date, child) =>
        _dateDrop(date, child, keyPrefix: 'agenda-drop'),
    entries: [
      for (final row in filtered) _calendarEntry(row),
      for (final event in _assessments.where(_matchesAssessment))
        if (event.status != 'withdrawn') _calendarAssessment(event),
    ],
  );
}
