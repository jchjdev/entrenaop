import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_opposition_goal.dart';

import 'trainer_client_goals_repository.dart';
import 'trainer_workout_repository.dart';

String _mark(double value, ProfessionalMarkUnit unit) => switch (unit) {
  ProfessionalMarkUnit.seconds => formatPerformanceTime(value),
  ProfessionalMarkUnit.repetitions => '${value.toInt()} rep',
  ProfessionalMarkUnit.meters =>
    '${value.toString().replaceFirst(RegExp(r'\.0$'), '')} m',
};
String _day(DateTime date) => '${date.day}/${date.month}/${date.year}';
String _error(Object error) =>
    error is FormatException ? error.message : trainerError(error);

String _latestGoalLine(ProfessionalOppositionGoalTarget target) {
  final meta = _mark(target.value, target.protocol.unit);
  if (!target.hasLatestEvidence) {
    return 'Meta: $meta · ${target.protocol.direction == ProfessionalBetterDirection.higher ? 'igualar o superar' : 'igualar o bajar'}';
  }
  final current = target.latest == null
      ? target.latestAt == null
            ? 'sin evaluación compatible'
            : 'sin marca válida'
      : _mark(target.latest!, target.protocol.unit);
  return 'Última: $current · Meta: $meta';
}

String _goalEvolution(ProfessionalOppositionGoalTarget target, double change) {
  if (change == 0) return 'Sin cambio respecto a la evaluación anterior';
  // El paso del protocolo evita enseñar residuos binarios de una resta decimal.
  final steps = (change.abs() / target.protocol.resolution).round();
  final magnitude = double.parse(
    (steps * target.protocol.resolution).toStringAsPrecision(15),
  );
  return '${change > 0 ? 'Mejora' : 'Variación desfavorable'} de ${_mark(magnitude, target.protocol.unit)} respecto a la evaluación anterior';
}

/// Resumen por pareja profesional: no consulta ni modifica la preparación
/// personal del alumno. El servidor decide edición y acceso a las marcas.
class TrainerClientGoalsPanel extends StatefulWidget {
  const TrainerClientGoalsPanel({
    super.key,
    required this.repository,
    required this.clientId,
    this.canEdit = true,
    this.compact = false,
  });
  final TrainerClientGoalsRepository repository;
  final String clientId;
  final bool canEdit;
  final bool compact;
  @override
  State<TrainerClientGoalsPanel> createState() =>
      _TrainerClientGoalsPanelState();
}

class _TrainerClientGoalsPanelState extends State<TrainerClientGoalsPanel> {
  ProfessionalOppositionGoal? _goal;
  bool _loading = true, _saving = false, _opening = false, _expanded = false;
  String? _message;
  ({String operation, int revision, ProfessionalOppositionGoalDraft draft})?
  _pending;
  int _request = 0;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrainerClientGoalsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != oldWidget.clientId ||
        widget.repository.scope != oldWidget.repository.scope) {
      _pending = null;
      _goal = null;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final value = await widget.repository.get(widget.clientId);
      if (mounted && request == _request) setState(() => _goal = value);
    } catch (e) {
      if (mounted && request == _request) setState(() => _message = _error(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    if (_opening || _saving || _pending != null || _goal == null) return;
    setState(() {
      _opening = true;
      _message = null;
    });
    try {
      final protocols = await widget.repository.protocols();
      if (!mounted) return;
      setState(() => _opening = false);
      _dialogOpen = true;
      final draft = await showDialog<ProfessionalOppositionGoalDraft>(
        context: context,
        builder: (context) => _GoalEditor(goal: _goal!, protocols: protocols),
      );
      if (draft != null && mounted) {
        _pending = (
          operation: trainerOperationId(),
          revision: _goal!.revision,
          draft: draft.normalized(),
        );
        await _save();
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      _dialogOpen = false;
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<bool> _save() async {
    final pending = _pending;
    if (pending == null || _saving) return false;
    final request = _request;
    final clientId = widget.clientId;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.repository.save(
        pending.operation,
        clientId,
        pending.revision,
        pending.draft,
      );
      if (!mounted || request != _request) return false;
      _pending = null;
      await _load();
      return true;
    } catch (e) {
      if (mounted && request == _request) {
        // Un rechazo transaccional es definitivo. Un fallo de transporte no
        // autoriza otra operación ni otro contenido hasta recuperar el recibo.
        if (e is PostgrestException &&
            ['22023', '42501', '40001', '22P02'].contains(e.code)) {
          _pending = null;
        }
        setState(() => _message = _error(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmPendingExit(BuildContext context) async {
    if (_pending == null) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardado pendiente de confirmación'),
        content: const Text(
          'Es posible que el objetivo se haya guardado. Confirma el resultado antes de salir para conservar el mismo envío.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar y salir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return false;
    // La navegación solo continúa tras recuperar el recibo de la misma
    // operación; nunca convierte una respuesta incierta en un descarte.
    return _save();
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    final date = goal?.targetDate;
    final now = DateTime.now();
    final remaining = date == null
        ? null
        : DateTime.utc(
            date.year,
            date.month,
            date.day,
          ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _pending != null,
      isBusy: () => _saving || _opening || _dialogOpen,
      confirmExit: _confirmPendingExit,
      child: EntrenaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    const Icon(Icons.flag_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Objetivo de oposición',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.canEdit &&
                        goal?.canEdit == true &&
                        _pending == null)
                      TextButton.icon(
                        onPressed: _loading || _saving || _opening
                            ? null
                            : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          goal?.revision == 0 ? 'Definir objetivo' : 'Editar',
                        ),
                      ),
                    IconButton(
                      tooltip: 'Actualizar objetivo',
                      onPressed: _loading || _saving || _pending != null
                          ? null
                          : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                );
                if (constraints.maxWidth < 500 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 4),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            if (_loading || _saving || _opening)
              const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_message!),
              ),
            if (_pending != null) ...[
              const Text(
                'Guardado pendiente de confirmación. Reintenta la misma operación antes de editar el objetivo.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: _saving ? null : _save,
                  child: const Text('Confirmar guardado pendiente'),
                ),
              ),
            ],
            if (goal != null && goal.revision == 0)
              const Text(
                'Define la convocatoria o preparación y las marcas que queréis alcanzar.',
              ),
            if (goal != null && goal.revision > 0) ...[
              Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
              if (date != null)
                Text(
                  '${_day(date)} · ${remaining == 0
                      ? 'Hoy'
                      : remaining! > 0
                      ? 'Faltan $remaining días'
                      : 'Fecha superada'}',
                ),
              const SizedBox(height: 12),
              for (final target
                  in (_expanded
                      ? goal.targets
                      : goal.targets.take(widget.compact ? 0 : 3)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        target.reached == true
                            ? Icons.check_circle_outline
                            : Icons.track_changes_outlined,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.protocol.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(_latestGoalLine(target)),
                            if (target.hasLatestEvidence &&
                                target.latestAt != null)
                              Text(
                                'Última evaluación: ${_day(target.latestAt!.toLocal())}${target.reached == true ? ' · Meta alcanzada en esta evaluación' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (target.favorableChange case final change?)
                              Text(_goalEvolution(target, change)),
                            Text(
                              target.best == null
                                  ? 'Sin marca válida comparable'
                                  : 'Mejor marca consultada: ${_mark(target.best!, target.protocol.unit)}${target.recordedAt == null ? '' : ' · ${_day(target.recordedAt!.toLocal())}'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (goal.targets.length > (widget.compact ? 0 : 3))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? 'Mostrar menos metas'
                          : widget.compact
                          ? 'Ver ${goal.targets.length} ${goal.targets.length == 1 ? 'marca' : 'marcas'} objetivo'
                          : 'Ver las ${goal.targets.length} metas',
                    ),
                  ),
                ),
              if (goal.targets.isEmpty)
                const Text(
                  'Puedes añadir metas desde las pruebas de tus baterías.',
                ),
              const SizedBox(height: 4),
              Text(
                'Marcas de tus evaluaciones completadas con el mismo protocolo. No calcula puntos ni aptitud oficial.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!goal.historyComplete)
                Text(
                  'Historial parcial: se consideran las últimas ${goal.evaluationsConsidered} evaluaciones completadas de este servicio.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetField {
  _TargetField(this.protocol, [double? value])
    : value = TextEditingController(
        text: value == null
            ? ''
            : protocol.unit == ProfessionalMarkUnit.seconds
            ? formatPerformanceTime(value)
            : value.toString().replaceFirst(RegExp(r'\.0$'), ''),
      );
  final ProfessionalAssessmentTest protocol;
  final TextEditingController value;
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({required this.goal, required this.protocols});
  final ProfessionalOppositionGoal goal;
  final List<ProfessionalAssessmentTest> protocols;
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final _title = TextEditingController(text: widget.goal.title);
  late DateTime? _date = widget.goal.targetDate;
  late final _targets = [
    for (final target in widget.goal.targets)
      _TargetField(target.protocol, target.value),
  ];
  ProfessionalAssessmentTest? _selected;
  String? _errorMessage;
  @override
  void dispose() {
    _title.dispose();
    for (final target in _targets) {
      target.value.dispose();
    }
    super.dispose();
  }

  Future<void> _datePicker() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200, 12, 31),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  void _save() {
    try {
      final draft = ProfessionalOppositionGoalDraft(
        title: _title.text,
        targetDate: _date,
        targets: [
          for (final field in _targets)
            ProfessionalOppositionGoalTarget(
              protocol: field.protocol,
              value: ProfessionalAssessmentValidator.parseMark(
                field.value.text,
                field.protocol,
              ),
            ),
        ],
      ).normalized();
      Navigator.of(context).pop(draft);
    } catch (e) {
      setState(() => _errorMessage = _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.protocols
        .where(
          (p) => !_targets.any(
            (t) =>
                t.protocol.protocolId == p.protocolId ||
                t.protocol.protocolFingerprint == p.protocolFingerprint,
          ),
        )
        .toList();
    return AlertDialog(
      title: const Text('Objetivo de oposición'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Convocatoria o preparación',
                  hintText: 'Por ejemplo: Policía Nacional · convocatoria 2027',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _datePicker,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _date == null ? 'Añadir fecha objetivo' : _day(_date!),
                    ),
                  ),
                  if (_date != null)
                    TextButton(
                      onPressed: () => setState(() => _date = null),
                      child: const Text('Sin fecha'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final field in _targets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: field.value,
                          decoration: InputDecoration(
                            labelText: field.protocol.name,
                            helperText:
                                '${field.protocol.unit == ProfessionalMarkUnit.seconds
                                    ? 'Tiempo: m:ss o segundos'
                                    : field.protocol.unit == ProfessionalMarkUnit.repetitions
                                    ? 'Repeticiones'
                                    : 'Metros'} · resolución ${field.protocol.resolution}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar meta de ${field.protocol.name}',
                        onPressed: () {
                          setState(() => _targets.remove(field));
                          field.value.dispose();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              if (_targets.length < 40 && available.isNotEmpty) ...[
                DropdownButtonFormField<ProfessionalAssessmentTest>(
                  key: ValueKey(available.map((p) => p.protocolId).join(',')),
                  isExpanded: true,
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: 'Prueba de tus baterías',
                  ),
                  items: [
                    for (final p in available)
                      DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.name} · v${p.protocolVersion}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selected = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => setState(() {
                            _targets.add(_TargetField(_selected!));
                            _selected = null;
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir meta'),
                  ),
                ),
              ],
              if (widget.protocols.isEmpty)
                const Text(
                  'Crea primero una batería en Pruebas y simulacros para disponer de protocolos comparables.',
                ),
              const SizedBox(height: 8),
              const Text(
                'Las condiciones de cada prueba se conservan. Cambiar una meta no modifica ni califica los resultados del alumno.',
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errorMessage!),
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
        FilledButton(onPressed: _save, child: const Text('Guardar objetivo')),
      ],
    );
  }
}
