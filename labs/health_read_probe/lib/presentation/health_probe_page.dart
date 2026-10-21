import 'package:device_activity_core/device_activity_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/local_running_health.dart';
import 'health_probe_cubit.dart';

class HealthProbePage extends StatefulWidget {
  const HealthProbePage({super.key});

  @override
  State<HealthProbePage> createState() => _HealthProbePageState();
}

class _HealthProbePageState extends State<HealthProbePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<HealthProbeCubit>().suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<HealthProbeCubit, HealthProbeState>(
    builder: (context, state) {
      final cubit = context.read<HealthProbeCubit>();
      final platform = cubit.source.platform;
      final data = state.read;
      final consent = state.consent;
      return Scaffold(
        appBar: AppBar(title: const Text('Ensayo de lectura')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(switch (platform) {
                LocalHealthPlatform.appleHealth => 'Salud de Apple',
                LocalHealthPlatform.healthConnect => 'Health Connect',
                LocalHealthPlatform.unsupported =>
                  'Se necesita un iPhone o Android',
              }, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'Solo lectura de carreras de los últimos siete días. Los datos permanecen en memoria: no hay cuenta, subida ni envío a entrenadores.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes retirar los permisos desde Salud o Health Connect. Vaciar la lectura no revoca el permiso del sistema.',
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: state.busy ? null : cubit.check,
                child: const Text('1. Comprobar disponibilidad'),
              ),
              if (state.availability case final availability?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(switch (availability) {
                    HealthStoreAvailability.available =>
                      'Almacén disponible en este dispositivo.',
                    HealthStoreAvailability.updateRequired => 'Instala o actualiza Health Connect y vuelve a comprobar.',
                    HealthStoreAvailability.unavailable =>
                      'El almacén de salud no está disponible.',
                    HealthStoreAvailability.unsupported =>
                      'Esta plataforma no permite realizar el ensayo móvil.',
                  }),
                ),
              FilledButton.tonal(
                onPressed:
                    !state.busy &&
                        state.availability == HealthStoreAvailability.available
                    ? cubit.authorize
                    : null,
                child: const Text('2. Solicitar lectura de entrenamientos'),
              ),
              if (consent != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(switch (consent) {
                    HealthReadConsent.granted =>
                      'Health Connect permite leer entrenamientos.',
                    HealthReadConsent.queryAllowedUnknown => 'Solicitud completada. Apple no revela si concediste lectura; una lista vacía no demuestra denegación.',
                    HealthReadConsent.denied => 'Lectura no concedida. Puedes revisar los permisos del sistema.',
                  }),
                ),
              FilledButton(
                onPressed:
                    !state.busy &&
                        const {
                          HealthReadConsent.granted,
                          HealthReadConsent.queryAllowedUnknown,
                        }.contains(consent)
                    ? cubit.read
                    : null,
                child: const Text('3. Leer carreras de los últimos 7 días'),
              ),
              TextButton(
                onPressed: cubit.clear,
                child: const Text('Vaciar lectura'),
              ),
              if (state.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.problem case final problem?)
                Text(switch (problem) {
                  HealthProbeProblem.unavailable =>
                    'No se puede acceder al almacén. Comprueba el dispositivo.',
                  HealthProbeProblem.permissionRequired => 'El permiso ya no está disponible. Vuelve a comprobar y solicitar lectura.',
                  HealthProbeProblem.invalidResponse => 'La respuesta no cumple el contrato del ensayo. No se muestran datos parciales.',
                  HealthProbeProblem.readFailed => 'La operación no se completó. Puedes comprobar y reintentar.',
                }, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (platform == LocalHealthPlatform.healthConnect)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Esta primera lectura de Android no atribuye distancia, pulso ni pausas a la sesión. Una carrera puede aparecer con esas métricas sin informar.',
                  ),
                ),
              if (data != null) ...[
                const Divider(height: 32),
                Text('Carreras legibles: ${data.activities.length}'),
                if (data.activities.isEmpty)
                  const Text(
                    'No se han obtenido carreras legibles en esta ventana.',
                  ),
                if (data.rejectedRecords > 0)
                  Text(
                    'Registros apartados por validación: ${data.rejectedRecords}',
                  ),
                if (data.truncated)
                  const Text(
                    'Lectura parcial: se alcanzó el límite del ensayo. No representa todo el historial.',
                  ),
                for (final activity in data.activities) _ActivityCard(activity),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.activity);
  final ExternalActivity activity;

  @override
  Widget build(BuildContext context) {
    String duration(Duration? value) => value == null
        ? 'No informado'
        : '${value.inMicroseconds / Duration.microsecondsPerSecond} s';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Carrera · ${activity.writerApplication ?? 'Origen sin informar'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Inicio UTC: ${activity.startedAtUtc!.toIso8601String()}'),
            Text('Entre inicio y fin: ${duration(activity.metrics.elapsed)}'),
            Text('Temporizador: ${duration(activity.metrics.timer)}'),
            Text(
              'Distancia: ${activity.metrics.distanceMeters == null ? 'No informada' : '${activity.metrics.distanceMeters} m'}',
            ),
            Text(
              'Zona de origen: ${activity.timeZoneId ?? (activity.startUtcOffset == null ? 'No informada' : 'Offset ${activity.startUtcOffset!.inMinutes} min')}',
            ),
          ],
        ),
      ),
    );
  }
}
