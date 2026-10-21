import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/trainer_progress.dart';

import 'trainer_client_workspace_repository.dart';
import 'trainer_csv_export.dart';
import 'trainer_workout_repository.dart';

String _error(Object error) =>
    error is FormatException ? error.message : trainerError(error);
String _day(DateTime day) => '${day.day}/${day.month}/${day.year}';

/// Ficha por identidad persistida: puede abrirse directamente o tras recarga.
class TrainerClientWorkspacePage extends StatefulWidget {
  const TrainerClientWorkspacePage({
    super.key,
    required this.repository,
    required this.clientId,
  });
  final TrainerClientWorkspaceRepository repository;
  final String clientId;
  @override
  State<TrainerClientWorkspacePage> createState() =>
      _TrainerClientWorkspacePageState();
}

class _TrainerClientWorkspacePageState
    extends State<TrainerClientWorkspacePage> {
  final _notes = TextEditingController(), _goal = TextEditingController();
  TrainerClientWorkspace? _workspace;
  TrainerClientProgressReport? _report;
  String? _errorMessage, _reportError, _notice;
  bool _loading = true, _reportLoading = false, _saving = false, _dirty = false;
  int _revision = 0, _reportRequest = 0;
  ({String operation, int revision, String notes, String goal})? _pending;
  late DateTime _start, _endExclusive;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _endExclusive = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    _start = _endExclusive.subtract(const Duration(days: 30));
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar las notas sin guardar?'),
          content: const Text(
            'Recargar sustituirá este borrador por la última revisión guardada. Los resultados del alumno no se modifican.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar borrador'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar y recargar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final workspace = await widget.repository.get(widget.clientId);
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _revision = workspace.revision;
        _notes.text = workspace.notes;
        _goal.text = workspace.goal;
        _dirty = false;
        _pending = null;
      });
      await _loadReport();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReport() async {
    final request = ++_reportRequest;
    setState(() {
      _reportLoading = true;
      _reportError = null;
      _report = null;
    });
    try {
      final report = await widget.repository.progress(
        widget.clientId,
        _start,
        _endExclusive,
      );
      if (mounted && request == _reportRequest) {
        setState(() => _report = report);
      }
    } catch (e) {
      if (mounted && request == _reportRequest) {
        setState(() => _reportError = _error(e));
      }
    } finally {
      if (mounted && request == _reportRequest) {
        setState(() => _reportLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_notes.text.trim().length > 2000 || _goal.text.trim().length > 500) {
      setState(
        () => _errorMessage =
            'Las notas admiten 2.000 caracteres y el objetivo 500.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
      _notice = null;
    });
    _pending ??= (
      operation: trainerOperationId(),
      revision: _revision,
      notes: _notes.text.trim(),
      goal: _goal.text.trim(),
    );
    final write = _pending!;
    try {
      final revision = await widget.repository.saveNotes(
        write.operation,
        widget.clientId,
        write.revision,
        notes: write.notes,
        goal: write.goal,
      );
      if (!mounted) return;
      setState(() {
        _revision = revision;
        _pending = null;
        _dirty = false;
        _notice = 'Notas internas guardadas.';
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200, 12, 31),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _endExclusive.subtract(const Duration(days: 1)),
      ),
    );
    if (range == null || !mounted) return;
    final start = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    if (end.difference(start).inDays > 366) {
      setState(() => _reportError = 'Selecciona como máximo 366 días.');
      return;
    }
    setState(() {
      _start = start;
      _endExclusive = end;
    });
    await _loadReport();
  }

  Future<void> _export() async {
    final report = _report, workspace = _workspace;
    if (report == null || workspace == null) return;
    try {
      final csv = trainerClientReportCsv(workspace.client.name, report);
      final downloaded = await downloadTrainerCsv(
        'informe-${workspaceDate(report.start)}-${workspaceDate(report.endExclusive)}.csv',
        csv,
      );
      if (!downloaded) await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        setState(
          () => _notice = downloaded
              ? 'Descarga del CSV iniciada.'
              : 'CSV copiado al portapapeles.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _reportError = _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspace;
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _dirty,
      isBusy: () => _saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(workspace?.client.name ?? 'Ficha del alumno'),
          actions: [
            IconButton(
              tooltip: 'Recargar ficha',
              onPressed: _loading || _saving ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_notice != null) Text(_notice!),
                if (workspace == null && !_loading)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar ficha'),
                  ),
                if (workspace != null) ...[
                  Text(
                    workspace.client.active
                        ? 'Servicio activo'
                        : workspace.client.archivedAt != null
                        ? 'Cliente archivado'
                        : 'Cliente inactivo',
                  ),
                  Text(
                    '${workspace.client.episodeCount} etapas del servicio · solo datos de tu relación profesional.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/clients/${widget.clientId}/workouts',
                        ),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Planificación y resultados'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/clients/${widget.clientId}/forms'),
                        icon: const Icon(Icons.assignment_outlined),
                        label: const Text('Formularios'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/clients/${widget.clientId}/assessments',
                        ),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Pruebas y simulacros'),
                      ),
                      if (workspace.relations.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/conversations/${workspace.client.activeRelationId ?? workspace.relations.first['id']}',
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Conversación'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Notas del preparador',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Privadas. No aparecen en la app del alumno ni en el informe exportado. El objetivo es una anotación tuya; no cambia pruebas o baremos.',
                  ),
                  Text('Revisión $_revision'),
                  TextField(
                    controller: _goal,
                    enabled:
                        workspace.canEditNotes && !_saving && _pending == null,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo interno',
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  TextField(
                    controller: _notes,
                    enabled:
                        workspace.canEditNotes && !_saving && _pending == null,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Notas internas',
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  if (_pending != null)
                    const Text(
                      'El guardado ya se envió. Reintenta para confirmar la misma revisión y contenido.',
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed:
                          !workspace.canEditNotes ||
                              _saving ||
                              (!_dirty && _pending == null)
                          ? null
                          : _save,
                      child: Text(
                        _saving
                            ? 'Guardando…'
                            : _pending == null
                            ? 'Guardar notas internas'
                            : 'Reintentar notas',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Etapas del servicio',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final relation in workspace.relations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Desde ${_day(DateTime.parse(relation['accepted_at'] as String).toLocal())}',
                      ),
                      subtitle: Text(
                        relation['ended_at'] == null
                            ? 'Activa'
                            : 'Finalizada ${_day(DateTime.parse(relation['ended_at'] as String).toLocal())}',
                      ),
                    ),
                  if (!workspace.relationsComplete)
                    const Text(
                      'Se muestran las últimas 50 etapas; esta lista es parcial.',
                    ),
                  const Divider(height: 40),
                  Text(
                    'Evolución del servicio',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${_day(_start)} – ${_day(_endExclusive.subtract(const Duration(days: 1)))}',
                  ),
                  const Text(
                    'Cumplimiento: fecha civil pautada. Resultados: agrupados por fecha de INICIO de la ejecución en UTC; no representan la fecha de cada serie.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _reportLoading ? null : _period,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Elegir periodo'),
                      ),
                      TextButton.icon(
                        onPressed: _reportLoading ? null : _loadReport,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar informe'),
                      ),
                      TextButton.icon(
                        onPressed: _report == null ? null : _export,
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar informe CSV'),
                      ),
                    ],
                  ),
                  if (_reportLoading)
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(),
                        Text(
                          'Cargando todas las páginas del periodo. El resumen aparecerá cuando esté completo.',
                        ),
                      ],
                    ),
                  if (_reportError != null)
                    Text(
                      _reportError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_report case final report?)
                    _ReportContent(report: report),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});
  final TrainerClientProgressReport report;
  String _value(num? value, String unit) => value == null
      ? 'Sin dato'
      : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} $unit';
  @override
  Widget build(BuildContext context) {
    final compliance = report.compliance;
    final fraction = compliance.completedFraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Datos completos cargados: ${report.assignments.length} pautas, ${report.sets.length} series y ${report.amrap.length} bloques AMRAP.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  fraction == null
                      ? 'Sin citas evaluables en este periodo'
                      : '${(fraction * 100).toStringAsFixed(0)} % de citas completadas',
                ),
                if (fraction != null) LinearProgressIndicator(value: fraction),
                Text(
                  '${compliance.completedCount}/${compliance.eligibleCount} citas evaluables · ${compliance.pendingCount} pendientes vencidas · ${compliance.inProgressCount} en curso · ${compliance.skippedCount} omitidas · ${compliance.abandonedCount} abandonadas',
                ),
                Text(
                  '${compliance.todayAndFutureCount} de hoy/futuras sin penalizar · ${compliance.cancelledExcluded} retiradas excluidas. Corte: ${_day(report.asOfDate)} UTC.',
                ),
                const Text(
                  'Completar una cita no implica haber completado todas sus series.',
                ),
              ],
            ),
          ),
        ),
        if (report.results.exercises.isEmpty)
          const Text(
            'No hay series de ejercicios con resultados comparables en este periodo.',
          ),
        for (final progress in report.results.exercises.values)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    report.exerciseName(progress.exerciseId),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${progress.count(TrainerProgressSetStatus.completed)} series completadas · ${progress.count(TrainerProgressSetStatus.skipped)} omitidas · ${progress.count(TrainerProgressSetStatus.pending)} pendientes',
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Medida registrada')),
                        DataColumn(label: Text('Observaciones')),
                        DataColumn(label: Text('Ausentes')),
                        DataColumn(label: Text('Mínimo')),
                        DataColumn(label: Text('Máximo')),
                      ],
                      rows: [
                        _metric('Repeticiones', progress.reps, 'rep'),
                        _metric('Duración', progress.durationSeconds, 's'),
                        _metric('Distancia', progress.distanceMeters, 'm'),
                        _metric('Carga externa', progress.loadKg, 'kg'),
                        _metric('Esfuerzo', progress.rpe, 'RPE'),
                        _metric('Margen', progress.rir, 'RIR'),
                      ],
                    ),
                  ),
                  const Text(
                    'Esta tabla resume campos generales de series completadas. Los resultados deportivos tipados se muestran aparte, con su protocolo y unidad. Los ausentes no se sustituyen por cero. No se calcula tonelaje ni 1RM.',
                  ),
                  for (final record in progress.records.where(
                    (r) =>
                        r.performancePrescription != null &&
                        r.performanceResult != null,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Registro tipado · ${record.performancePrescription!.exerciseCode} · protocolo ${record.performancePrescription!.protocolKey} v${record.performancePrescription!.protocolVersion}: '
                        '${_value(record.performanceResult!.value, record.performancePrescription!.unit)}'
                        '${record.performanceResult!.succeeded == null
                            ? ''
                            : record.performanceResult!.succeeded!
                            ? ' · Éxito declarado'
                            : ' · Fallo declarado'}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (report.results.amrapBlocks.isNotEmpty) ...[
          Text(
            'AMRAP: resultados de bloque',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final block in report.results.amrapBlocks)
            Text(
              '${_day(block.recordDate.value)} UTC · Bloque ${block.blockOrder + 1}: ${block.completedRounds} rondas completas'
              '${block.partialItemOrder == null ? '' : ' · ejercicio ${block.partialItemOrder! + 1}: ${block.partialReps} rep adicionales'}',
            ),
          Text(
            '${report.results.amrapReferenceSetsExcluded} referencias de receta AMRAP excluidas de los totales de series.',
          ),
        ],
      ],
    );
  }

  DataRow _metric(
    String label,
    TrainerRecordedMetricSummary metric,
    String unit,
  ) => DataRow(
    cells: [
      DataCell(Text(label)),
      DataCell(Text('${metric.recordedCount}')),
      DataCell(Text('${metric.missingCount}')),
      DataCell(Text(_value(metric.minimum, unit))),
      DataCell(Text(_value(metric.maximum, unit))),
    ],
  );
}

String trainerClientReportCsv(
  String clientName,
  TrainerClientProgressReport report,
) {
  const columns = [
    'tipo',
    'alumno',
    'periodo_desde',
    'periodo_hasta_exclusivo',
    'criterio_fecha',
    'fecha',
    'id',
    'ejecucion',
    'ejercicio_id',
    'ejercicio',
    'estado',
    'repeticiones',
    'duracion_s',
    'distancia_m',
    'carga_kg',
    'rpe',
    'rir',
    'rondas_completas',
    'repeticiones_parciales',
    'objetivo_repeticiones',
    'objetivo_duracion_s',
    'objetivo_distancia_m',
    'objetivo_carga_kg',
    'objetivo_rpe',
    'objetivo_rir',
    'medicion_tipificada',
    'valor_tipificado',
    'exito_declarado',
    'protocolo',
    'version_protocolo',
    'ejercicio_codigo',
    'version_ejercicio',
    'unidad_tipificada',
    'prescripcion_tipificada_json',
    'resultado_tipificado_json',
  ];
  final units = <String, String>{
    for (final progress in report.results.exercises.values)
      for (final record in progress.records)
        if (record.performancePrescription != null)
          record.id: record.performancePrescription!.unit,
  };
  final rows = <List<Object?>>[columns];
  List<Object?> row(String kind, String basis, Map<String, dynamic> value) => [
    kind,
    clientName,
    workspaceDate(report.start),
    workspaceDate(report.endExclusive),
    basis,
    value['record_date'],
    value['id'],
    value['execution_id'],
    value['exercise_id'],
    value['exercise_name'] ?? value['template_name'],
    value['status'],
    value['actual_reps'],
    value['actual_duration_seconds'],
    value['actual_distance_meters'],
    value['actual_load_kg'],
    value['actual_rpe'],
    value['actual_rir'],
    value['completed_rounds'],
    value['partial_reps'],
    value['target_reps'],
    value['target_duration_seconds'],
    value['target_distance_meters'],
    value['target_load_kg'],
    value['target_rpe'],
    value['target_rir'],
    (value['performance_prescription'] as Map?)?['measurement'],
    (value['performance_result'] as Map?)?['value'],
    (value['performance_result'] as Map?)?['succeeded'],
    (value['performance_prescription'] as Map?)?['protocol_key'],
    (value['performance_prescription'] as Map?)?['protocol_version'],
    (value['performance_prescription'] as Map?)?['exercise_code'],
    (value['performance_prescription'] as Map?)?['exercise_version'],
    units[value['id']],
    value['performance_prescription'] == null
        ? null
        : jsonEncode(value['performance_prescription']),
    value['performance_result'] == null
        ? null
        : jsonEncode(value['performance_result']),
  ];
  for (final assignment in report.assignments) {
    rows.add(row('pauta', 'fecha_civil_pautada', assignment));
  }
  for (final set in report.sets) {
    rows.add(row('serie', 'fecha_inicio_ejecucion_UTC', set));
  }
  for (final block in report.amrap) {
    rows.add(row('amrap', 'fecha_inicio_ejecucion_UTC', block));
  }
  if (rows.length == 1) {
    rows.add([
      'periodo_sin_registros',
      clientName,
      workspaceDate(report.start),
      workspaceDate(report.endExclusive),
      'cumplimiento_fecha_pautada_resultados_inicio_UTC',
      ...List<Object?>.filled(columns.length - 5, null),
    ]);
  }
  return trainerCsvEncode(rows);
}
