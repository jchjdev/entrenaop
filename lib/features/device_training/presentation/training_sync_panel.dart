import 'package:flutter/material.dart';

import '../domain/training_delivery.dart';

/// La conexión y el envío manual consultan la misma preferencia del servidor.
/// Mostrar este control nunca activa el consentimiento de la cuenta.
class TrainingSyncPanel extends StatefulWidget {
  const TrainingSyncPanel({
    super.key,
    required this.repository,
    this.refreshToken,
    this.interactionEnabled = true,
  });

  final TrainingSyncRepository repository;
  final Object? refreshToken;
  final bool interactionEnabled;

  @override
  State<TrainingSyncPanel> createState() => _TrainingSyncPanelState();
}

class _TrainingSyncPanelState extends State<TrainingSyncPanel> {
  TrainingSyncSettings? _settings;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrainingSyncPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _load();
  }

  Future<void> _load({bool? enabled}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await widget.repository.syncSettings(enabled: enabled);
      if (mounted) setState(() => _settings = settings);
    } catch (error) {
      if (mounted) {
        setState(() {
          // Una respuesta perdida puede haber aplicado el cambio. Consultar
          // antes de anunciar un estado o permitir otra escritura.
          _settings = null;
          _error = error is TrainingDeliveryException
              ? error.code
              : 'garmin_unavailable';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final enabled = settings?.enabled;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sincronización automática'),
              subtitle: Text(
                _busy
                    ? 'Consultando el estado del envío automático…'
                    : enabled == null
                    ? 'Estado del envío automático sin confirmar.'
                    : enabled
                    ? 'Activada · tus sesiones compatibles se envían a Garmin.'
                    : 'Desactivada · tus nuevas sesiones no se envían solas.',
              ),
              value: enabled ?? false,
              onChanged: _busy || settings == null || !widget.interactionEnabled
                  ? null
                  : (value) => _load(enabled: value),
            ),
            const Text(
              'Incluye las sesiones asignadas por tu entrenador y tu plan adaptativo, desde hoy hasta los próximos 14 días, con sus cambios y cancelaciones. Funciona aunque EntrenaOP esté cerrada.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Después, Garmin Connect debe sincronizar con el reloj. Enviado a Garmin no significa recibido en el reloj.',
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Cómo funciona'),
              children: const [
                Text(
                  '1. Tu entrenador o el plan adaptativo asigna una sesión con fecha. Guardarla solo en la biblioteca no la envía.\n'
                  '2. Con el automático activado, EntrenaOP envía las sesiones compatibles a Garmin. Las fechas pasadas quedan fuera.\n'
                  '3. Sincroniza Garmin Connect con el reloj y comprueba su calendario de entrenamiento.\n\n'
                  'Desactivar esta opción detiene nuevos envíos; no retira lo que ya se ha enviado.',
                ),
                SizedBox(height: 12),
              ],
            ),
            if (settings != null &&
                (settings.pending > 0 || settings.review > 0))
              Text(
                '${settings.pending} pendientes · ${settings.review} requieren revisión',
              ),
            if (_error != null) ...[
              Text(switch (_error) {
                'account_changed' =>
                  'Tu sesión ha cambiado. Vuelve a abrir esta pantalla.',
                'access_required' =>
                  'Necesitas Pro vigente o tu servicio de entrenador activo.',
                'permission_denied' ||
                'connection_required' ||
                'reauthorization_required' =>
                  'Revisa la conexión y el permiso de envío en Garmin.',
                _ => 'No se pudo confirmar el ajuste. Consulta el estado antes de volver a cambiarlo.',
              }),
              if (_error != 'account_changed')
                TextButton.icon(
                  onPressed: _busy || !widget.interactionEnabled
                      ? null
                      : () => _load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Consultar de nuevo'),
                ),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
