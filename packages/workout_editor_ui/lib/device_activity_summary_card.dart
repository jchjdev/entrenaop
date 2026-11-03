import 'package:flutter/material.dart';
import 'package:workout_core/device_activity_summary.dart';

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
            : 'Resultados incorporados a la sesión',
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
}
