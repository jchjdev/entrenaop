import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../domain/activity_result.dart';
import 'activity_result_cubit.dart';

class ActivityResultPage extends StatefulWidget {
  const ActivityResultPage({super.key, required this.repository});
  final ActivityResultRepository repository;
  @override
  State<ActivityResultPage> createState() => _ActivityResultPageState();
}

class _ActivityResultPageState extends State<ActivityResultPage> {
  late final ActivityResultCubit cubit = ActivityResultCubit(
    widget.repository,
    () => const Uuid().v4(),
  )..load();
  final Map<String, String> _selected = {};
  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Carreras recibidas de Garmin')),
    body: BlocBuilder<ActivityResultCubit, ActivityResultState>(
      bloc: cubit,
      builder: (context, state) {
        final review = state.review;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.busy) const LinearProgressIndicator(),
                if (state.executionId != null) ...[
                  const Icon(Icons.check_circle_outline, size: 48),
                  const Text('Sesión completada con los datos del reloj.'),
                  const Text(
                    'Ya puedes consultar el resultado en tu semana y en el historial. Tu entrenador verá el mismo resultado.',
                  ),
                  FilledButton(
                    onPressed: cubit.load,
                    child: const Text('Volver a las carreras'),
                  ),
                ] else ...[
                  if (state.problem != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_problem(state.problem!)),
                    ),
                  if (review == null)
                    ..._catalog(state)
                  else
                    ..._review(state, review),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: state.busy ? null : cubit.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar carreras'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  List<Widget> _catalog(ActivityResultState state) {
    final catalog = state.catalog;
    return [
      const Text(
        'Después de sincronizar el reloj con Garmin Connect, tus carreras aparecerán aquí.',
      ),
      const Text(
        'Recibir una carrera no completa la semana: revisa sus vueltas y confirma a qué sesión corresponde.',
      ),
      if (catalog != null && catalog.problems.isNotEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Hay una actividad pendiente de revisión técnica. Actualizar no vuelve a descargar un archivo ya consumido.',
          ),
        ),
      if (catalog != null && catalog.runs.isEmpty && !state.busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Todavía no hay carreras recibidas.'),
        ),
      if (catalog != null)
        for (final run in catalog.runs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_date(run.startedAt)} UTC · ${_distance(run.meters)} · ${_time(run.seconds)}',
                  ),
                  if (run.executionId != null)
                    const Text('Asociada a una sesión completada')
                  else ...[
                    if (catalog.appointments.isEmpty)
                      const Text(
                        'No hay sesiones pendientes compatibles en tu agenda.',
                      ),
                    if (catalog.appointments.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue:
                            catalog.appointments.any(
                              (v) => v.id == _selected[run.id],
                            )
                            ? _selected[run.id]
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sesión de tu semana',
                        ),
                        items: [
                          for (final appointment in catalog.appointments)
                            DropdownMenuItem(
                              value: appointment.id,
                              child: Text(
                                '${appointment.date} · ${appointment.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: state.busy
                            ? null
                            : (id) => setState(() {
                                if (id != null) _selected[run.id] = id;
                              }),
                      ),
                      FilledButton.tonal(
                        onPressed: state.busy || _selected[run.id] == null
                            ? null
                            : () => cubit.preview(run.id, _selected[run.id]!),
                        child: const Text('Revisar vueltas y sesión'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
    ];
  }

  List<Widget> _review(ActivityResultState state, ActivityResultReview review) {
    final locked = state.busy || state.retryingConfirmation;
    return [
      Text(review.name, style: Theme.of(context).textTheme.titleLarge),
      Text(
        '${_distance(review.meters)} · ${_time(review.seconds)}'
        '${review.averageHeartRate == null ? '' : ' · ${review.averageHeartRate} ppm medias'}',
      ),
      const SizedBox(height: 12),
      const Text(
        'Comprueba cada correspondencia. Las sugerencias se basan en la estructura de las vueltas; puedes corregirlas.',
      ),
      const Text(
        'El archivo original conserva las décimas. El historial de series guarda el tiempo redondeado al segundo.',
      ),
      for (var index = 0; index < state.rows.length; index++)
        _row(state, review, index, locked),
      if (review.offsetMinutes == null)
        DropdownButtonFormField<int>(
          initialValue: state.offsetMinutes,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Zona horaria al realizar la carrera',
          ),
          items: [
            for (var minutes = -840; minutes <= 840; minutes += 15)
              DropdownMenuItem(value: minutes, child: Text(_offset(minutes))),
          ],
          onChanged: locked
              ? null
              : (value) => cubit.edit(offsetMinutes: value),
        )
      else
        Text(
          'Hora de salida: ${_date(review.startedAt.add(Duration(minutes: review.offsetMinutes!)))} ${_offset(review.offsetMinutes!)}',
        ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: state.rpe,
        decoration: const InputDecoration(
          labelText: 'Tu esfuerzo global (1–10)',
        ),
        items: [
          for (var value = 1; value <= 10; value++)
            DropdownMenuItem(value: value, child: Text('$value / 10')),
        ],
        onChanged: locked ? null : (value) => cubit.edit(rpe: value),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: state.reviewed,
        title: const Text(
          'He revisado las vueltas y la sesión. Al completar, los datos formarán parte de mi historial y del seguimiento de mi entrenador.',
        ),
        onChanged: locked ? null : (value) => cubit.edit(reviewed: value),
      ),
      if (!validLapAssignments(state.rows, review.laps))
        const Text(
          'Asigna las vueltas pendientes sin repetirlas, o marca expresamente el paso como no realizado.',
        ),
      if (state.retryingConfirmation && !state.busy)
        const Text(
          'La respuesta no se ha confirmado. Reintentar recupera la misma operación; también puedes actualizar para consultar si ya se completó.',
        ),
      FilledButton.icon(
        onPressed: state.canConfirm ? cubit.confirm : null,
        icon: const Icon(Icons.check),
        label: Text(
          state.retryingConfirmation
              ? 'Reintentar confirmación'
              : 'Completar sesión con estos datos',
        ),
      ),
    ];
  }

  Widget _row(
    ActivityResultState state,
    ActivityResultReview review,
    int index,
    bool locked,
  ) {
    final row = state.rows[index];
    void change(LapAssignment value) {
      final rows = [...state.rows];
      rows[index] = value;
      cubit.edit(rows: rows);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${row.label}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paso no realizado'),
              value: row.skipped,
              onChanged: locked
                  ? null
                  : (value) => change(row.select(skipped: value)),
            ),
            if (!row.skipped) ...[
              _lapPicker(
                'Vuelta de trabajo',
                row.laps,
                review.laps,
                locked ? null : (value) => change(row.select(laps: value)),
              ),
              if (row.requiresRecovery)
                _lapPicker(
                  'Vuelta de recuperación',
                  row.recoveryLaps,
                  review.laps,
                  locked
                      ? null
                      : (value) => change(row.select(recoveryLaps: value)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lapPicker(
    String label,
    List<int> selected,
    List<RecordedLap> laps,
    ValueChanged<List<int>>? changed,
  ) {
    final chosen = laps.where((lap) => selected.contains(lap.index));
    final seconds = chosen.fold<double>(0, (total, lap) => total + lap.seconds);
    final meters = chosen.fold<double>(0, (total, lap) => total + lap.meters);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        selected.isEmpty
            ? 'Elegir vueltas'
            : 'Vueltas ${selected.map((i) => i + 1).join(', ')} · ${_time(seconds)} · ${_distance(meters)}',
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: changed == null
          ? null
          : () async {
              final draft = selected.toSet();
              final value = await showDialog<List<int>>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, update) => AlertDialog(
                    title: Text(label),
                    content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Selecciona una vuelta o varias consecutivas del mismo paso.',
                            ),
                            for (final lap in laps)
                              CheckboxListTile(
                                value: draft.contains(lap.index),
                                title: Text(
                                  '${lap.index + 1} · ${_time(lap.seconds)} · ${_distance(lap.meters)}',
                                ),
                                onChanged: (checked) => update(() {
                                  if (checked == true) {
                                    draft.add(lap.index);
                                  } else {
                                    draft.remove(lap.index);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, draft.toList()..sort()),
                        child: const Text('Usar estas vueltas'),
                      ),
                    ],
                  ),
                ),
              );
              if (value != null && mounted) changed(value);
            },
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _distance(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';
String _time(double seconds) {
  final tenths = (seconds * 10).round(), whole = (seconds * 10).round() ~/ 10;
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}.${tenths % 10}';
}

String _offset(int minutes) =>
    'UTC${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
String _problem(String code) => switch (code) {
  'account_changed' => 'Tu cuenta ha cambiado. Vuelve a abrir esta pantalla.',
  'activity_already_confirmed' =>
    'Esta carrera ya tiene un resultado. Actualiza la lista.',
  'stale_activity' || 'stale_review' || 'stale_prescription' =>
    'La actividad o la sesión han cambiado. Actualiza y vuelve a revisarlas.',
  'source_not_available' || 'source_not_allowed' =>
    'La sesión ya no está disponible para completar con esta carrera.',
  'invalid_mapping' => 'Revisa las vueltas: no pueden repetirse ni faltar recuperaciones prescritas.',
  'invalid_activity_clock' ||
  'invalid_offset' => 'Revisa la fecha y la zona horaria de la actividad.',
  _ => 'No se ha podido confirmar la operación. Puedes reintentar o actualizar su estado.',
};
