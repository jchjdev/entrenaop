import 'package:flutter/material.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/running_step.dart';

class DeviceActivitySummaryCard extends StatelessWidget {
  const DeviceActivitySummaryCard({
    super.key,
    required this.result,
    this.showName = false,
  });
  final DeviceActivitySummary result;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final source = r.provider == 'garmin' ? 'Garmin' : 'Apple Watch';
    final date = r.startedAt.toLocal();
    final seconds = r.seconds.round();
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final label = switch (r.state) {
      'unassigned' =>
        '${r.provider == 'garmin' ? 'Garmin' : 'Apple Watch'} · Pendiente de asociar',
      'test' => 'Prueba · no completa la sesión',
      'review' => '$source · Pendiente de revisión',
      _ =>
        r.executionId == null
            ? 'Resultado recibido de $source'
            : 'Resultados incorporados de $source',
    };
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('device-result-${r.provider}-${r.id}'),
        leading: Icon(
          Icons.watch_outlined,
          color: r.state == 'associated'
              ? Colors.lightGreen
              : Colors.orangeAccent,
        ),
        title: Text(showName ? r.name : label),
        subtitle: Text(
          '${showName ? '$label\n' : ''}$time${r.meters == null ? '' : ' · ${(r.meters! / 1000).toStringAsFixed(2)} km'}',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (r.scheduledName case final name? when name.isNotEmpty)
            Text('Pauta identificada: $name'),
          Text(
            '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          ),
          if (r.paceSecondsPerKm case final pace?)
            Text('Ritmo medio calculado: ${_paceLabel(pace)}'),
          if (r.averageHeartRate case final value?)
            Text('FC media: $value ppm'),
          if (r.maxHeartRate case final value?) Text('FC máxima: $value ppm'),
          if (r.effortScore case final value?)
            Text('Esfuerzo registrado en Salud: $value/10'),
          if (r.intervalCount > 0)
            Text(
              '${r.intervalCount} ${r.provider == 'garmin' ? 'vueltas' : 'intervalos'} disponibles',
            ),
          const SizedBox(height: 8),
          if (r.detailsIncomplete)
            const Text(
              'Desglose parcial: las fases conservan el orden del reloj. No se asignan a series ni se estiman las distancias ausentes.',
            ),
          if (r.intervals.any((part) => part.phaseFromPrescription))
            const Text(
              'Tipos de fase interpretados según la pauta. Las fases dudosas quedan sin identificar.',
            ),
          if (r.intervals.isNotEmpty)
            ExpansionTile(
              key: PageStorageKey('recorded-intervals-${r.provider}-${r.id}'),
              title: Text(
                r.intervals.length == 1
                    ? '1 fase registrada'
                    : '${r.intervals.length} fases registradas',
              ),
              children: [
                for (final part in r.intervals)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      switch (part.phaseKind) {
                        RunningStepKind.rest ||
                        RunningStepKind.recovery => Icons.pause_circle_outline,
                        null => Icons.help_outline,
                        _ => Icons.directions_run,
                      },
                      color: switch (part.phaseKind) {
                        RunningStepKind.warmup => Colors.redAccent,
                        RunningStepKind.cooldown => Colors.green,
                        RunningStepKind.run => Colors.blueAccent,
                        _ => Theme.of(context).colorScheme.onSurfaceVariant,
                      },
                    ),
                    title: Text(
                      '${part.index}. ${part.phaseKind?.label ?? 'Fase sin identificar'}',
                    ),
                    subtitle: Text(
                      [
                        formatPerformanceTime(part.seconds),
                        if (part.meters != null)
                          '${part.meters!.toStringAsFixed(1)} m',
                        if (part.paceSecondsPerKm case final pace?)
                          'Ritmo ${_paceLabel(pace)}',
                        if (part.averageHeartRate != null)
                          '${part.averageHeartRate} lpm',
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
          if (r.executionId == null)
            Text(
              r.state == 'unassigned'
                  ? 'Actividad recibida en tu cuenta. Todavía no está asociada a una pauta ni completa una sesión.'
                  : r.state == 'test'
                  ? 'Actividad identificada como prueba. Se conserva separada del resultado deportivo.'
                  : r.state == 'review'
                  ? 'El entrenamiento o sus datos necesitan revisión antes de incorporarlos como entrenamiento completado.'
                  : 'La actividad corresponde a esta pauta. El resumen del reloj no acredita el resultado individual de cada paso ni la valoración de esfuerzo.',
            ),
        ],
      ),
    );
  }

  static String _paceLabel(double pace) {
    final seconds = pace.round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}/km';
  }
}
