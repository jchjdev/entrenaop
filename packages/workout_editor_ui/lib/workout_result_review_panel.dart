import 'package:flutter/material.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/workout_result_review.dart';

class WorkoutResultReviewControls extends StatelessWidget {
  const WorkoutResultReviewControls({
    super.key,
    required this.session,
    required this.onlyDifferences,
    required this.onFilterChanged,
    this.loadHistory,
  });
  final ReviewSession session;
  final bool onlyDifferences;
  final ValueChanged<bool> onFilterChanged;
  final ReviewHistoryLoader? loadHistory;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Solo diferencias con la pauta'),
        subtitle: const Text(
          'Incluye omisiones y datos incompletos. No es una nota deportiva.',
        ),
        value: onlyDifferences,
        onChanged: onFilterChanged,
      ),
      if (loadHistory != null)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Comparar con otra sesión'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog.fullscreen(
                child: WorkoutSessionComparison(
                  current: session,
                  loadHistory: loadHistory!,
                ),
              ),
            ),
          ),
        ),
      if (onlyDifferences)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Los valores iguales a la pauta se ocultan. AMRAP conserva su resultado por bloque.',
          ),
        ),
    ],
  );
}

class WorkoutSessionComparison extends StatefulWidget {
  const WorkoutSessionComparison({
    super.key,
    required this.current,
    required this.loadHistory,
  });
  final ReviewSession current;
  final ReviewHistoryLoader loadHistory;
  @override
  State<WorkoutSessionComparison> createState() =>
      _WorkoutSessionComparisonState();
}

class _WorkoutSessionComparisonState extends State<WorkoutSessionComparison> {
  final List<ReviewSession> _sessions = [];
  Object? _cursor;
  bool _loading = true, _hasMore = true;
  String? _error, _selectedId;
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
      final page = await widget.loadHistory(_cursor);
      if (!mounted) return;
      setState(() {
        final seen = _sessions.map((s) => s.id).toSet();
        _sessions.addAll(
          page.sessions.where(
            (s) => widget.current.canCompare(s) && seen.add(s.id),
          ),
        );
        _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        _selectedId ??= _sessions.firstOrNull?.id;
        _cursor = page.nextCursor;
        _hasMore = _cursor != null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo consultar el historial. Puedes reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous = _sessions.where((s) => s.id == _selectedId).firstOrNull;
    final pairs = previous == null
        ? const <ReviewPair>[]
        : compareReviewSessions(widget.current, previous);
    final groups = <String, List<ReviewPair>>{};
    for (final pair in pairs) {
      final set = pair.current;
      if (set.format == 'amrap') continue;
      (groups['${set.block}:${set.item}:${set.exerciseId}:${set.format}'] ??=
              [])
          .add(pair);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar sesiones'),
        leading: IconButton(
          tooltip: 'Cerrar comparación',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.current.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Actual: ${_date(widget.current.startedAt)} · versión ${widget.current.version}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Misma sesión y versión. Compara marcas y contexto; un día aislado no determina tu evolución.',
                ),
                if (_sessions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedId),
                    initialValue: _selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sesión anterior',
                    ),
                    items: [
                      for (final session in _sessions)
                        DropdownMenuItem(
                          value: session.id,
                          child: Text(
                            '${_date(session.startedAt)} · ${session.status == 'abandoned' ? 'Abandonada' : 'Completada'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selectedId = value),
                  ),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null) Text(_error!),
                if (!_loading && _sessions.isEmpty && _error == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _hasMore
                          ? 'No hay sesiones comparables en esta página. Puedes consultar más historial.'
                          : 'No hay otra sesión anterior de esta misma versión en el historial disponible.',
                    ),
                  ),
                if (!_loading && (_hasMore || _error != null))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.history),
                      label: Text(
                        _error != null
                            ? 'Reintentar historial'
                            : 'Cargar más historial',
                      ),
                    ),
                  ),
                if (previous != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Esfuerzo global · anterior: ${_effort(previous.finalRpe)} · actual: ${_effort(widget.current.finalRpe)}',
                  ),
                  const Text(
                    'Δ = actual menos anterior. Más o menos no significa mejor o peor. «—» indica dato ausente.',
                  ),
                  for (final block in {
                    ...widget.current.amrap.map((r) => r.block),
                    ...previous.amrap.map((r) => r.block),
                  })
                    Card(
                      child: ListTile(
                        title: Text('AMRAP · Bloque ${block + 1}'),
                        subtitle: Text(
                          'Anterior: ${_amrap(previous, block)}\nActual: ${_amrap(widget.current, block)}',
                        ),
                      ),
                    ),
                  for (final group in groups.values)
                    Card(
                      child: ExpansionTile(
                        title: Text(group.first.current.exerciseName),
                        subtitle: Text(
                          '${group.first.current.blockName} · ${group.length} ${group.first.current.format == 'running' ? 'tramos' : 'series'}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          for (final pair in group) _ComparisonRow(pair: pair),
                        ],
                      ),
                    ),
                  if (previous.sets.length != widget.current.sets.length)
                    const Text(
                      'El número de posiciones difiere. Las posiciones sin correspondencia no se emparejan.',
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.pair});
  final ReviewPair pair;
  @override
  Widget build(BuildContext context) {
    final current = pair.current, previous = pair.previous;
    final keys = {
      ...?previous?.actual.keys,
      ...current.actual.keys,
      ...current.targets.keys,
    }..removeAll({'paceMin', 'paceMax'});
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Serie ${(current.order ?? 0) + 1} · anterior: ${_status(previous?.status)} · actual: ${_status(current.status)}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (previous == null)
            const Text(
              'Sin correspondencia inequívoca de ejercicio y posición.',
            ),
          if (pair.changedPrescription)
            const Text(
              'La pauta o el contexto cambió: revisa los objetivos antes de interpretar las marcas.',
            ),
          if (pair.changedPrescription)
            Text(
              'Objetivos anteriores: ${_targets(previous!.targets)}\nObjetivos actuales: ${_targets(current.targets)}',
            ),
          if (current.format == 'amrap')
            const Text(
              'Receta AMRAP: consulta las vueltas y parciales de cada sesión; no son series realizadas.',
            ),
          for (final key in keys) ...[
            const SizedBox(height: 6),
            Text(
              '${_metricName(key)} · anterior ${_value(key, previous?.actual[key])} → actual ${_value(key, current.actual[key])}'
              '${previous?.actual[key] != null && current.actual[key] != null ? ' · Δ ${_delta(key, current.actual[key]! - previous!.actual[key]!)}' : ''}',
            ),
            if (pair.changedPrescription &&
                (previous?.targets[key] != null ||
                    current.targets[key] != null))
              Text(
                'Pauta: ${_value(key, previous?.targets[key])} → ${_value(key, current.targets[key])}',
              ),
          ],
          const Divider(),
        ],
      ),
    );
  }
}

String _date(DateTime date) {
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _status(String? status) => switch (status) {
  'completed' => 'completada',
  'skipped' => 'omitida',
  'pending' => 'pendiente',
  _ => 'sin registro',
};
String _metricName(String key) => switch (key) {
  'reps' => 'Repeticiones',
  'load' => 'Peso',
  'rir' => 'RIR',
  'rpe' => 'RPE',
  'time' => 'Tiempo',
  'distance' => 'Distancia',
  'pace' => 'Ritmo',
  'paceMin' => 'Ritmo mínimo',
  'paceMax' => 'Ritmo máximo',
  'recoveryTime' => 'Tiempo de recuperación',
  'recoveryDistance' => 'Distancia de recuperación',
  _ => 'Valor',
};
String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String _value(String key, num? value) {
  if (value == null) return '—';
  return switch (key) {
    'time' || 'recoveryTime' => formatPerformanceTime(value.toDouble()),
    'pace' ||
    'paceMin' ||
    'paceMax' => '${formatPerformanceTime(value.toDouble())}/km',
    'load' => '${_number(value)} kg',
    'distance' || 'recoveryDistance' => '${_number(value)} m',
    _ => _number(value),
  };
}

String _delta(String key, num delta) =>
    '${delta < 0 ? '−' : '+'}${_value(key, delta.abs())}';

String _amrap(ReviewSession session, int block) {
  final result = session.amrap.where((r) => r.block == block).firstOrNull;
  if (result == null) return 'Sin registro';
  return '${result.rounds} vueltas completas${result.partialItem == null ? '' : ' · ejercicio ${result.partialItem! + 1}: ${result.partialReps} rep adicionales'}';
}

String _effort(num? value) =>
    value == null ? 'sin registro' : '${_number(value)}/10';
String _targets(Map<String, num> values) => values.isEmpty
    ? 'Sin objetivo numérico'
    : values.entries
          .map((e) => '${_metricName(e.key)} ${_value(e.key, e.value)}')
          .join(' · ');
