import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/training_delivery.dart';
import 'training_delivery_cubit.dart';
import 'training_sync_panel.dart';

class TrainingDeliveryPage extends StatefulWidget {
  const TrainingDeliveryPage({super.key, required this.repository});
  final TrainingDeliveryRepository repository;
  @override
  State<TrainingDeliveryPage> createState() => _TrainingDeliveryPageState();
}

class _TrainingDeliveryPageState extends State<TrainingDeliveryPage> {
  late final cubit = TrainingDeliveryCubit(widget.repository)..load();
  bool reviewed = false;
  int syncRevision = 0;

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  String date(String value) {
    final d = DateTime.tryParse(value);
    return d == null
        ? value
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String pace(double value) =>
      '${value ~/ 60}:${(value.round() % 60).toString().padLeft(2, '0')}';
  String measure(TrainingStep step) => step.measure == 'manual'
      ? 'Hasta pulsar Lap'
      : step.measure == 'seconds'
      ? pace(step.value!)
      : step.measure == 'reps'
      ? '${step.value!.toStringAsFixed(0)} rep'
      : '${step.value! % 1 == 0 ? step.value!.toStringAsFixed(0) : step.value.toString()} m';
  String error(String code) => switch (code) {
    'account_changed' =>
      'Tu sesión ha cambiado. Vuelve a entrar antes de enviar.',
    'access_required' =>
      'Necesitas Pro vigente o tu servicio de entrenador activo.',
    'connection_required' ||
    'permission_denied' ||
    'reauthorization_required' =>
      'Revisa la conexión con Garmin y el permiso para enviar sesiones.',
    'unsupported_prescription' || 'invalid_prescription' => 'Esta sesión contiene pasos que todavía no podemos representar fielmente en Garmin. No se ha enviado.',
    'source_not_available' || 'source_not_allowed' || 'stale_prescription' => 'La pauta ya no está disponible o ha cambiado. Actualiza y revisa de nuevo.',
    'delivery_needs_review' => 'Esta cita ya tiene un envío con otra versión o conexión. Revisa Garmin antes de hacer otro envío.',
    'connection_busy' =>
      'Hay otra operación con Garmin en curso. Actualiza dentro de un momento.',
    'rate_limited' =>
      'Hay demasiadas solicitudes. Espera antes de volver a intentarlo.',
    'delivery_uncertain' => 'No se pudo confirmar el envío. Revisa Garmin; no repetimos la creación para evitar duplicados.',
    _ => 'No se pudo completar la operación. Actualiza el estado antes de volver a intentarlo.',
  };
  Widget receipt(TrainingReceipt r) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.name} · ${date(r.date)}'),
          const SizedBox(height: 8),
          Text(switch (r.status) {
            'sent' => 'Enviada y confirmada en el calendario de Garmin. Sincroniza Garmin Connect y comprueba el reloj.',
            'cancelled' => 'Retirada de Garmin por cancelación de la cita. Tu historial de actividades se conserva.',
            'updating' => 'Actualizando la sesión en Garmin.',
            'cancelling' => 'Retirando la sesión de Garmin.',
            'uncertain' => 'Envío sin confirmar. Revisa Garmin; no se creará otra copia automáticamente.',
            'failed' => error(r.error ?? 'garmin_unavailable'),
            'workout_created' =>
              'Entrenamiento creado; falta confirmar su fecha en Garmin.',
            _ => 'Envío en curso. Actualiza el estado antes de repetirlo.',
          }),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sesiones en Garmin')),
    body: BlocBuilder<TrainingDeliveryCubit, TrainingDeliveryState>(
      bloc: cubit,
      builder: (context, state) {
        final preview = state.preview, catalog = state.catalog;
        final prior = catalog?.deliveries
            .where((r) => r.scheduledId == state.selected?.id)
            .firstOrNull;
        final result = state.receipt ?? prior;
        final blocked =
            result != null &&
            [
              'sent',
              'uncertain',
              'creating',
              'scheduling',
              'refreshing',
              'updating',
              'cancelling',
              'cancelled',
            ].contains(result.status);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.repository
                    case final TrainingSyncRepository syncRepository) ...[
                  TrainingSyncPanel(
                    repository: syncRepository,
                    refreshToken: syncRevision,
                    interactionEnabled: !state.busy,
                  ),
                  const Divider(height: 32),
                ],
                const Text(
                  'Elige una sesión compatible de tu entrenador o tu plan adaptativo. Revisa la fecha y todos los pasos antes de enviarla.',
                ),
                if (state.busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error(state.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (catalog != null && catalog.candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No hay sesiones compatibles pendientes del algoritmo o de tu entrenador disponibles para enviar.',
                    ),
                  ),
                for (final candidate
                    in catalog?.candidates ?? <TrainingCandidate>[])
                  ListTile(
                    selected: candidate.id == state.selected?.id,
                    title: Text(candidate.name),
                    subtitle: Text(
                      '${date(candidate.date)} · ${candidate.source == 'coach' ? 'Entrenador' : 'Plan adaptativo'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !state.busy,
                    onTap: () {
                      setState(() => reviewed = false);
                      cubit.select(candidate);
                    },
                  ),
                if (preview != null) ...[
                  const Divider(height: 32),
                  Text(
                    preview.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${date(preview.date)} · ${preview.steps.length} pasos'),
                  if (preview.description.isNotEmpty) Text(preview.description),
                  const SizedBox(height: 12),
                  for (final (index, step) in preview.steps.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text('${index + 1}'),
                      title: Text(
                        '${step.description} · ${measure(step)}${step.loadKg == null ? '' : ' · ${step.loadKg} kg'}',
                      ),
                      subtitle: step.fast == null
                          ? null
                          : Text(
                              'Ritmo: ${pace(step.fast!)}–${pace(step.slow!)} min/km',
                            ),
                    ),
                  Text(
                    preview.sport == 'strength'
                        ? 'Se envían series, repeticiones o tiempo, carga indicada y descansos. RIR y esfuerzo orientativos se muestran como instrucciones.'
                        : 'Andar, trotar y el esfuerzo orientativo se muestran como instrucciones. Los ritmos se envían como objetivos cuando están prescritos.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('He revisado la fecha y los pasos.'),
                    value: reviewed,
                    onChanged: state.busy || blocked
                        ? null
                        : (value) => setState(() => reviewed = value ?? false),
                  ),
                  FilledButton(
                    onPressed: !reviewed || state.busy || blocked
                        ? null
                        : cubit.send,
                    child: const Text('Enviar a Garmin'),
                  ),
                ],
                if (state.receipt != null) receipt(state.receipt!),
                if (catalog != null && catalog.deliveries.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Últimos envíos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final r in catalog.deliveries) receipt(r),
                ],
                TextButton.icon(
                  onPressed: state.busy
                      ? null
                      : () {
                          setState(() => reviewed = false);
                          cubit.load();
                          setState(() => syncRevision++);
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar estado'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
