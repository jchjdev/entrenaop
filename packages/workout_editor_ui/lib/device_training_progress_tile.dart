import 'package:flutter/material.dart';
import 'package:workout_core/device_training_progress.dart';

class DeviceTrainingProgressTile extends StatelessWidget {
  const DeviceTrainingProgressTile({
    super.key,
    required this.progress,
    this.showName = true,
  });

  final DeviceTrainingProgress progress;
  final bool showName;

  String get _label => switch (progress.phase) {
    DeviceTrainingPhase.notSent => 'No enviada',
    DeviceTrainingPhase.pending => 'Pendiente de envío automático',
    DeviceTrainingPhase.sending => 'Enviando a Garmin',
    DeviceTrainingPhase.sent => 'Enviada al calendario de Garmin',
    DeviceTrainingPhase.changePending => 'Cambios pendientes de enviar',
    DeviceTrainingPhase.updating => 'Actualizando en Garmin',
    DeviceTrainingPhase.cancellationPending => 'Retirada pendiente en Garmin',
    DeviceTrainingPhase.cancelling => 'Retirando de Garmin',
    DeviceTrainingPhase.cancelled => 'Retirada confirmada en Garmin',
    DeviceTrainingPhase.retryPending => 'Pendiente de reintento',
    DeviceTrainingPhase.review => 'Requiere revisión',
    DeviceTrainingPhase.blocked => 'Envío bloqueado',
    DeviceTrainingPhase.unsupported => 'Sesión no compatible con Garmin',
    DeviceTrainingPhase.started => 'Sesión con ejecución registrada',
    DeviceTrainingPhase.completed =>
      progress.resultsConfirmed
          ? 'Resultados del reloj incorporados'
          : 'Sesión completada',
  };

  String get _detail => switch (progress.reason) {
    'auto_disabled' => 'El alumno debe activar la sincronización automática desde su conexión con Garmin. Sincronizar Connect no inicia este envío.',
    'past_date' => 'La fecha ya pasó. El automático no envía citas pasadas.',
    'outside_window' => 'Entrará en el envío automático cuando quede dentro de los próximos 14 días.',
    'appointment_cancelled' =>
      'La pauta está retirada y no tiene una entrega confirmada en Garmin.',
    'historical_preserved' => 'La pauta se retiró después de su fecha. La entrega histórica se conserva.',
    'access_required' =>
      'La conexión requiere Pro o un servicio de entrenador vigente.',
    'connection_required' => 'El alumno debe conectar Garmin en EntrenaOP.',
    'permission_denied' || 'reauthorization_required' || 'connection_changed' =>
      'Revisa la conexión Garmin del alumno y sus permisos antes de continuar.',
    'provider_rejected' ||
    'unsupported_prescription' ||
    'invalid_prescription' =>
      progress.hasDelivery
          ? 'Los cambios no se pueden enviar fielmente. La versión anterior puede seguir en Garmin; revisa su calendario.'
          : 'Esta receta contiene un formato, ejercicio o paso que todavía no podemos representar fielmente en Garmin.',
    'delivery_uncertain' ||
    'delivery_needs_review' ||
    'invalid_provider_response' => 'No se ha podido confirmar la entrega. Revisa Garmin antes de repetir: no se creará otra copia automáticamente.',
    'source_changed' || 'stale_prescription' =>
      'La pauta o su autorización ha cambiado. Actualiza antes de continuar.',
    _ => switch (progress.phase) {
      DeviceTrainingPhase.sent => 'Sincroniza Garmin Connect con el reloj. Enviado a Garmin no acredita recepción en el dispositivo.',
      DeviceTrainingPhase.cancelled => 'Se ha retirado de Garmin el entrenamiento de EntrenaOP. Las actividades realizadas se conservan.',
      DeviceTrainingPhase.started =>
        'No se modifica automáticamente una sesión que ya tiene una ejecución.',
      DeviceTrainingPhase.completed =>
        progress.resultsConfirmed
            ? 'La actividad fue revisada e incorporada a esta cita y al historial.'
            : 'La cita está completada. Este estado no acredita por sí solo un resultado del reloj.',
      DeviceTrainingPhase.review => 'La operación necesita revisión; actualizar el estado no autoriza crear otra copia.',
      _ => 'El servidor procesa los envíos, cambios y retiradas en segundo plano. Actualiza para consultar su avance.',
    },
  };

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final date = DateTime.parse(p.date);
    final attention = {
      DeviceTrainingPhase.review,
      DeviceTrainingPhase.blocked,
      DeviceTrainingPhase.unsupported,
    }.contains(p.phase);
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('delivery-${p.id}'),
        leading: Icon(
          attention ? Icons.info_outline : Icons.watch_outlined,
          color: attention ? const Color(0xffffab70) : null,
        ),
        title: Text(showName ? p.name : 'Garmin'),
        subtitle: Text(_label),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${date.day}/${date.month}/${date.year}'),
          const SizedBox(height: 8),
          Text(_detail),
        ],
      ),
    );
  }
}
