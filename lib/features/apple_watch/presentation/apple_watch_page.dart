import 'package:flutter/material.dart';

import '../domain/apple_training.dart';
import 'apple_results_coordinator.dart';
import 'apple_training_coordinator.dart';

import 'package:workout_editor_ui/device_activity_summary_card.dart';

class AppleWatchPage extends StatefulWidget {
  const AppleWatchPage({
    super.key,
    required this.service,
    required this.onOpenHealth,
    this.results,
    this.training,
    this.onReviewResult,
    this.onOpenExecution,
  });
  final AppleTrainingService service;
  final VoidCallback onOpenHealth;
  final AppleResultsCoordinator? results;
  final AppleTrainingCoordinator? training;
  final void Function(String id, String scheduledId)? onReviewResult;
  final void Function(String executionId)? onOpenExecution;
  @override
  State<AppleWatchPage> createState() => _AppleWatchPageState();
}

class _AppleWatchPageState extends State<AppleWatchPage> {
  late final AppleTrainingService _service;
  AppleCatalog? _catalog;
  AppleAuthorization? _authorization;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = widget.service;
    widget.training?.addListener(_trainingChanged);
    _run(_load);
  }

  void _trainingChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.training?.catalog case final catalog?) _catalog = catalog;
      if (widget.training?.enabled == true) {
        _authorization = AppleAuthorization.authorized;
      }
    });
  }

  @override
  void dispose() {
    widget.training?.removeListener(_trainingChanged);
    super.dispose();
  }

  Future<void> _load() async {
    await widget.training?.refresh();
    final authorization = await _service.scheduler.status();
    if (mounted) setState(() => _authorization = authorization);
    final catalog = await _service.repository.load();
    if (mounted) setState(() => _catalog = catalog);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = _explain(
            e is AppleTrainingFailure ? e.code : 'apple_unavailable',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(AppleCandidate candidate) async {
    final preview = await _service.repository.preview(candidate.id);
    if (!mounted) return;
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              preview.prescription.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Carrera · ${candidate.date}'),
            const SizedBox(height: 16),
            for (final entry in preview.prescription.steps.indexed)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey(
                    'apple-preview-${candidate.id}-${entry.$1}',
                  ),
                  leading: CircleAvatar(child: Text('${entry.$1 + 1}')),
                  title: Text(entry.$2.description),
                  subtitle: Text(_goal(entry.$2)),
                  children: [
                    if (entry.$2.fast != null)
                      ListTile(
                        title: Text(
                          'Ritmo: ${_time(entry.$2.fast!)}–${_time(entry.$2.slow!)} /km',
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Apple lo añadirá a Entreno del reloj emparejado con este iPhone. Las recuperaciones se muestran como intervalos de recuperación; mantén la indicación de trote, caminar o descanso que aparece en su nombre.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.watch_outlined),
              label: const Text('Programar en Apple Watch'),
            ),
          ],
        ),
      ),
    );
    if (send != true) return;
    await _service.send(candidate.id, preview);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Apple Watch'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : () => _run(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _run(_load),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tus carreras en Entreno',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa el iPhone emparejado con tu Apple Watch. Requiere iOS 18 y watchOS 11 o posteriores; un Series 2 no es compatible.',
            ),
            const SizedBox(height: 12),
            if (widget.training case final training?) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sincronizar agenda automáticamente'),
                subtitle: const Text(
                  'Envía las carreras de tu preparador y del plan automático, con sus cambios y cancelaciones. Se comprueba al abrir EntrenaOP y mientras la usas en el iPhone emparejado.',
                ),
                value: training.enabled,
                onChanged: training.supported && !training.configuring
                    ? training.enable
                    : null,
              ),
              if (training.busy) const LinearProgressIndicator(),
              if (training.error case final error?) Text(error),
              if (training.lastChecked case final date?)
                Text(
                  'Agenda comprobada: ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                ),
              if (training.enabled)
                const Text(
                  'No necesitas programar cada carrera a mano. La llegada al reloj depende de la conexión entre Apple Watch y este iPhone.',
                ),
              const Divider(),
            ],
            if (widget.results case final results?)
              ListenableBuilder(
                listenable: results,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recibir resultados automáticamente'),
                      subtitle: const Text(
                        'Al abrir o volver a EntrenaOP, recoge tus pautas realizadas en Apple Watch. Comparte el tiempo, la distancia y las pulsaciones disponibles con el preparador de esa sesión. Puedes desactivarlo cuando quieras.',
                      ),
                      value: results.catalog?.enabled == true,
                      onChanged:
                          results.reader.supported && !results.configuring
                          ? results.enable
                          : null,
                    ),
                    if (results.catalog?.enabled == true)
                      TextButton.icon(
                        onPressed:
                            results.reader.supported && !results.configuring
                            ? () => results.enable(true)
                            : null,
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Revisar permisos de Salud'),
                      ),
                    if (results.busy) const LinearProgressIndicator(),
                    if (results.error case final error?) Text(error),
                    if (results.lastChecked case final date?)
                      Text(
                        'Última comprobación: ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      ),
                    TextButton.icon(
                      onPressed: results.busy ? null : results.refresh,
                      icon: const Icon(Icons.sync),
                      label: const Text('Comprobar resultados ahora'),
                    ),
                    if (results.catalog?.enabled == true)
                      Text(
                        results.backgroundEnabled
                            ? 'Recogida en segundo plano activada. iOS decide cuándo entrega los avisos de Salud; también se comprueba al abrir EntrenaOP.'
                            : 'Se comprueban los resultados al abrir EntrenaOP. La recogida en segundo plano aún no está activada en esta instalación.',
                      ),
                    if (results.catalog?.enabled == true &&
                        results.catalog!.results.isEmpty)
                      const Text(
                        'Aún no hay resultados vinculados. Guarda el entrenamiento en el reloj y espera a que aparezca en Fitness. Salud debe permitir leer Entrenamientos. Si Apple no aporta la referencia de la pauta, no se asociará por nombre o fecha.',
                      ),
                    for (final result in results.catalog?.results ?? []) ...[
                      DeviceActivitySummaryCard(result: result, showName: true),
                      if (result.executionId case final execution?)
                        TextButton.icon(
                          onPressed: () =>
                              widget.onOpenExecution?.call(execution),
                          icon: const Icon(Icons.history),
                          label: const Text('Ver en mi historial'),
                        )
                      else if (widget.onReviewResult != null &&
                          result.scheduledId != null)
                        TextButton.icon(
                          onPressed: () => widget.onReviewResult!(
                            result.id,
                            result.scheduledId!,
                          ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text(
                            result.state == 'test'
                                ? 'Ver intervalos de prueba'
                                : 'Revisar intervalos y completar sesión',
                          ),
                        ),
                      if (result.state != 'test' && result.executionId == null)
                        TextButton.icon(
                          onPressed: () => results.classify(result.id, true),
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Es una actividad de prueba'),
                        ),
                    ],
                    const Divider(),
                  ],
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, semanticsLabel: 'Error: $_error'),
                ),
              ),
            if (_authorization == AppleAuthorization.unsupported)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Este dispositivo no permite programar entrenamientos. Abre EntrenaOP actualizado en el iPhone emparejado.',
                  ),
                ),
              ),
            if (_authorization != null &&
                _authorization != AppleAuthorization.authorized &&
                _authorization != AppleAuthorization.unsupported)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        _authorization = await _service.scheduler.authorize();
                        await _load();
                      }),
                child: const Text('Autorizar Apple Watch'),
              ),
            if (_authorization == AppleAuthorization.denied ||
                _authorization == AppleAuthorization.restricted)
              const Text(
                'El permiso está denegado o restringido. Revísalo en Ajustes del iPhone antes de volver a autorizar.',
              ),
            if (_authorization == AppleAuthorization.authorized)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text('Programación autorizada en este iPhone'),
              ),
            if (_catalog?.allowed == false)
              const Text(
                'El envío requiere Pro o un servicio de entrenador vigente. Puedes retirar las sesiones que ya hayas programado.',
              ),
            const SizedBox(height: 16),
            if (_catalog != null)
              Text(
                'Próximos 14 días',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (_catalog?.candidates.isEmpty == true)
              const Text(
                'No hay carreras pautadas pendientes en este periodo.',
              ),
            for (final candidate in _catalog?.candidates ?? <AppleCandidate>[])
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(candidate.name),
                  subtitle: Text(candidate.date),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      _busy ||
                          widget.training?.busy == true ||
                          _catalog?.allowed != true ||
                          _authorization != AppleAuthorization.authorized
                      ? null
                      : () => _run(() => _preview(candidate)),
                ),
              ),
            const SizedBox(height: 20),
            if (_catalog?.receipts.isNotEmpty == true)
              Text(
                'Programadas desde EntrenaOP',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            for (final receipt in _catalog?.receipts ?? <AppleReceipt>[])
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('apple-receipt-${receipt.id}'),
                  leading: Icon(
                    receipt.needsRemoval
                        ? Icons.sync_problem
                        : Icons.watch_outlined,
                  ),
                  title: Text(receipt.name),
                  subtitle: Text(
                    '${receipt.date} · ${receipt.status == 'submitted'
                        ? 'Programada en este iPhone'
                        : receipt.status == 'removed'
                        ? 'Retirada'
                        : 'Pendiente de confirmar'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (receipt.needsRemoval &&
                              receipt.status != 'removed')
                            const Text(
                              'La cita se retiró de la agenda. Retírala también desde este iPhone para actualizar Apple.',
                            ),
                          const Text(
                            'Este estado confirma la programación local; no acredita que el reloj ya la haya recibido ni que se haya completado.',
                          ),
                          if (receipt.status != 'removed')
                            TextButton.icon(
                              onPressed:
                                  _busy ||
                                      widget.training?.busy == true ||
                                      _authorization !=
                                          AppleAuthorization.authorized
                                  ? null
                                  : () => _run(() async {
                                      // Una retirada manual no debe deshacerse
                                      // en la siguiente conciliación automática.
                                      await widget.training?.enable(false);
                                      await _service.withdraw(receipt.id);
                                      await _load();
                                    }),
                              icon: const Icon(Icons.event_busy_outlined),
                              label: Text(
                                widget.training?.enabled == true
                                    ? 'Retirar y desactivar envío automático'
                                    : 'Retirar de Apple Watch',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Activa la sincronización de agenda para programar las carreras desde este iPhone. También puedes revisar y programar una sesión concreta. El envío y la recogida de resultados se autorizan por separado.',
            ),
            TextButton.icon(
              onPressed: widget.onOpenHealth,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Leer actividades de Salud'),
            ),
          ],
        ),
      ),
    ),
  );
  static String _time(num seconds) {
    final n = seconds.round();
    return '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}';
  }

  static String _goal(AppleStep s) => switch (s.measure) {
    'manual' => 'Hasta avanzar manualmente',
    'seconds' => _time(s.value!),
    'meters' => '${s.value} m',
    _ => 'No compatible',
  };
  static String _explain(String code) => switch (code) {
    'access_required' =>
      'Necesitas Pro o un servicio de entrenador vigente para enviar sesiones.',
    'account_changed' => 'La cuenta ha cambiado. Vuelve a abrir esta pantalla.',
    'stale_prescription' => 'La pauta cambió. Actualiza y revisa su versión actual antes de enviarla.',
    'connection_busy' =>
      'Hay una programación en curso. Espera unos instantes y actualiza.',
    'already_completed' => 'Apple ya marca esta sesión como realizada. Lee sus resultados desde Salud.',
    'capacity_reached' => 'Apple tiene su calendario lleno. Retira una sesión antes de añadir otra.',
    'permission_required' =>
      'Autoriza la programación de entrenamientos en este iPhone.',
    'unsupported_prescription' => 'Apple no puede representar esta sesión completa. No se ha confirmado su envío.',
    'delivery_uncertain' =>
      'Apple no ha confirmado el cambio. Actualiza antes de repetirlo.',
    'update_required' =>
      'Actualiza EntrenaOP en el iPhone para disponer de WorkoutKit.',
    _ => 'No se pudo completar la operación. Actualiza y vuelve a comprobarlo.',
  };
}
