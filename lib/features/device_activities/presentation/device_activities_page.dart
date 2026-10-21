import 'dart:async';

import 'package:device_activity_core/device_activity_core.dart';
import 'package:device_health/device_health.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../domain/running_history.dart';
import 'device_activities_cubit.dart';

class DeviceActivitiesPage extends StatefulWidget {
  const DeviceActivitiesPage({
    super.key,
    required this.ownerId,
    required this.health,
    required this.history,
  });
  final String ownerId;
  final LocalRunningHealth health;
  final RunningHistoryRepository history;
  @override
  State<DeviceActivitiesPage> createState() => _DeviceActivitiesPageState();
}

class _DeviceActivitiesPageState extends State<DeviceActivitiesPage>
    with WidgetsBindingObserver {
  late DeviceActivitiesCubit _cubit;
  void _create() {
    _cubit = DeviceActivitiesCubit(
      ownerId: widget.ownerId,
      health: widget.health,
      history: widget.history,
    );
    unawaited(_cubit.initialize());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  @override
  void didUpdateWidget(covariant DeviceActivitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ownerId != oldWidget.ownerId ||
        widget.health != oldWidget.health ||
        widget.history != oldWidget.history) {
      _cubit.deactivate();
      unawaited(_cubit.close());
      _create();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cubit.suspend();
    }
    if (state == AppLifecycleState.resumed) _cubit.resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _clear() async {
    final cubit = _cubit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => EntrenaDialog(
        title: const Text('¿Borrar el historial importado?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se borrarán las carreras y sus revisiones guardadas en tu cuenta de EntrenaOP. Los originales de Salud se conservan.',
            ),
            const SizedBox(height: 20),
            EntrenaDialogActions(
              primaryLabel: 'Cancelar',
              onPrimary: () => context.pop(false),
              secondary: [
                OutlinedButton(
                  style: EntrenaButtonStyles.destructive(context),
                  onPressed: () => context.pop(true),
                  child: const Text('Borrar historial'),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
    if (confirmed == true && mounted && identical(cubit, _cubit)) {
      await cubit.clearHistory();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DeviceActivitiesCubit, DeviceActivitiesState>(
    bloc: _cubit,
    builder: (context, state) {
      final canRead = state.availability == HealthStoreAvailability.available;
      final pending = state.pendingSave || state.pendingClear;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Historial de carreras'),
          actions: [
            IconButton(
              tooltip: 'Actualizar historial',
              onPressed: state.busy ? null : _cubit.initialize,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Conecta tus carreras',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Lee tus carreras de los últimos siete días y elige cuáles guardar en tu cuenta de EntrenaOP.',
              ),
              const SizedBox(height: 12),
              if (canRead)
                FilledButton.icon(
                  onPressed: state.busy || pending ? null : _cubit.read,
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Leer carreras de Salud'),
                ),
              if (state.availability != null && !canRead)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(switch (state.availability!) {
                    HealthStoreAvailability.notIntegrated => 'La lectura de Health Connect aún no está integrada. Puedes consultar las carreras que ya guardaste en tu cuenta.',
                    HealthStoreAvailability.unsupported => 'La lectura de Salud está disponible en iPhone. Aquí puedes consultar tu historial guardado.',
                    HealthStoreAvailability.updateRequired =>
                      'El almacén de salud necesita una actualización.',
                    _ => 'Salud no está disponible ahora en este dispositivo.',
                  }),
                ),
              if (state.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.historyProblem case final problem?)
                _ProblemText(_historyMessage(problem)),
              if (state.readProblem case final problem?)
                _ProblemText(switch (problem) {
                  HealthReadProblem.permissionRequired => 'No se pudo acceder a los entrenamientos. Revisa los permisos en Salud.',
                  HealthReadProblem.invalidResponse => 'No se pudo validar la lectura de Salud. No se ha guardado.',
                  _ => 'No se pudieron leer las carreras. Puedes volver a intentarlo.',
                }),
              if (state.receipt case final receipt?)
                Text(
                  'Último guardado: ${receipt.inserted} nuevas, ${receipt.updated} revisiones y ${receipt.unchanged} ya guardadas.',
                ),
              if (state.pendingSave)
                FilledButton(
                  onPressed: state.busy ? null : _cubit.save,
                  child: const Text('Reintentar el mismo guardado'),
                ),
              if (state.pendingClear)
                FilledButton(
                  onPressed: state.busy ? null : _cubit.clearHistory,
                  child: const Text('Reintentar el mismo borrado'),
                ),
              if (state.preview.isNotEmpty) ...[
                const Divider(height: 32),
                Text(
                  'Revisar antes de guardar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Solo las carreras seleccionadas se enviarán y guardarán en tu cuenta.',
                ),
                for (final item in state.preview)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.unchanged
                                  ? 'Ya guardada'
                                  : item.previous == null
                                  ? 'Nueva carrera'
                                  : 'Guardar esta nueva revisión',
                            ),
                            value: state.selected.contains(item.id),
                            onChanged:
                                state.busy ||
                                    pending ||
                                    item.unchanged ||
                                    item.collision
                                ? null
                                : (v) => _cubit.select(item.id, v ?? false),
                          ),
                          _ActivitySummary(item.activity),
                          if (item.previous != null && !item.unchanged) ...[
                            const SizedBox(height: 8),
                            const Text('Versión guardada:'),
                            _ActivitySummary(item.previous!.activity),
                            const Text(
                              'La versión anterior se conservará. Revisa los cambios antes de seleccionar.',
                            ),
                          ],
                          if (item.collision)
                            const _ProblemText(
                              'La misma revisión contiene datos distintos. No se guardará.',
                            ),
                        ],
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed:
                      state.busy ||
                          pending ||
                          state.connection == null ||
                          state.selected.isEmpty
                      ? null
                      : _cubit.save,
                  child: Text(
                    'Guardar seleccionadas (${state.selected.length})',
                  ),
                ),
              ],
              if (state.rejected > 0)
                Text('No se pudieron validar ${state.rejected} registros.'),
              if (state.truncated)
                const Text(
                  'La lectura es parcial: se alcanzó el límite. Tu historial guardado se conserva.',
                ),
              const Divider(height: 32),
              Text(
                'Guardadas en tu cuenta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!state.busy &&
                  state.history.isEmpty &&
                  state.historyProblem == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Todavía no has guardado carreras.'),
                ),
              for (final item in state.history)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ActivitySummary(item.activity),
                  ),
                ),
              if (state.next != null)
                TextButton(
                  onPressed: state.busy ? null : _cubit.loadMore,
                  child: const Text('Cargar más carreras'),
                ),
              if (state.connection != null)
                TextButton.icon(
                  onPressed: state.busy ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar historial importado'),
                ),
              const SizedBox(height: 12),
              const Text(
                'Retirar el permiso en Salud impide nuevas lecturas. El historial que elegiste guardar se conserva hasta que lo borres o elimines tu cuenta.',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary(this.activity);
  final ExternalActivity activity;
  @override
  Widget build(BuildContext context) {
    final distance = activity.metrics.distanceMeters;
    final start = activity.startedAtUtc;
    String duration(Duration? value) {
      if (value == null) return 'Sin informar';
      final seconds = (value.inMicroseconds / Duration.microsecondsPerSecond)
          .round();
      final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
      return '${h > 0 ? '$h h ' : ''}$m min ${s.toString().padLeft(2, '0')} s';
    }

    final source = switch (activity.writerApplication) {
      'com.garmin.connect.mobile' => 'Garmin Connect',
      null => 'Salud · origen sin informar',
      final value => value,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          distance == null
              ? 'Distancia sin informar'
              : '${NumberFormat('0.00', 'es').format(distance / 1000)} km',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (start != null)
          Text(
            '${DateFormat('dd/MM/yyyy · HH:mm', 'es').format(start.toLocal())} · hora del dispositivo',
          ),
        Text('Duración: ${duration(activity.metrics.elapsed)}'),
        Text('Temporizador: ${duration(activity.metrics.timer)}'),
        Text(source),
        if (activity.metrics.paceUsing(ActivityTimeBasis.timer)
            case final pace?)
          Text(
            pace.secondsPerKm > const Duration(days: 7).inSeconds
                ? 'Ritmo calculado: ${NumberFormat.scientificPattern('es').format(pace.secondsPerKm)} s/km'
                : 'Ritmo calculado: ${duration(Duration(microseconds: (pace.secondsPerKm * Duration.microsecondsPerSecond).round()))}/km',
          ),
      ],
    );
  }
}

class _ProblemText extends StatelessWidget {
  const _ProblemText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String _historyMessage(RunningHistoryProblem problem) => switch (problem) {
  RunningHistoryProblem.accountChanged =>
    'La cuenta ha cambiado. Vuelve a abrir tu historial.',
  RunningHistoryProblem.conflict || RunningHistoryProblem.staleGeneration => 'El historial ha cambiado. Actualiza y vuelve a revisar las carreras antes de guardar.',
  RunningHistoryProblem.historicalRevision => 'Esta lectura corresponde a una revisión anterior. Se conserva la versión actual.',
  RunningHistoryProblem.revisionCollision =>
    'La misma revisión tiene contenido distinto. No se ha guardado el lote.',
  RunningHistoryProblem.operationReused => 'La orden no corresponde a esta selección. Vuelve a leer y revisar las carreras.',
  RunningHistoryProblem.limitReached => 'Se ha alcanzado el límite de historial de tu cuenta. Puedes seguir consultándolo.',
  RunningHistoryProblem.invalidData =>
    'No se pudieron validar los datos. No se guardó el lote.',
  RunningHistoryProblem.unavailable => 'No se pudo confirmar la operación. Comprueba la conexión y vuelve a intentarlo.',
};
