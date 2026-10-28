import 'package:device_health/device_health.dart';
import 'package:flutter/material.dart';

import '../domain/garmin_connection.dart';

class DeviceConnectionsPage extends StatefulWidget {
  const DeviceConnectionsPage({
    super.key,
    required this.ownerId,
    required this.health,
    required this.garmin,
    required this.onOpenHealth,
    required this.onOpenGarmin,
    this.onOpenAppleWatch,
  });

  final String ownerId;
  final LocalRunningHealth health;
  final GarminConnectionRepository garmin;
  final Future<void> Function() onOpenHealth, onOpenGarmin;
  final Future<void> Function()? onOpenAppleWatch;

  @override
  State<DeviceConnectionsPage> createState() => _DeviceConnectionsPageState();
}

class _DeviceConnectionsPageState extends State<DeviceConnectionsPage> {
  late Future<HealthStoreAvailability> _health;
  late Future<GarminConnectionSnapshot> _garmin;

  void _load() {
    // Consultar disponibilidad no pide permisos ni lee actividades del móvil.
    _health = widget.health.availability();
    _garmin = widget.garmin.load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DeviceConnectionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.health != widget.health ||
        oldWidget.garmin != widget.garmin) {
      _load();
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_load);
    try {
      await Future.wait<Object>([_health, _garmin]);
    } catch (_) {
      // Cada tarjeta conserva su error; una conexión no oculta a la otra.
    }
  }

  Future<void> _open(Future<void> Function() action) async {
    await action();
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Dispositivos y conexiones', maxLines: 2),
      toolbarHeight: 76 * MediaQuery.textScalerOf(context).scale(1),
      actions: [
        IconButton(
          tooltip: 'Actualizar conexiones',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Gestiona tus conexiones y los datos que compartes con EntrenaOP.',
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<HealthStoreAvailability>(
                      key: ValueKey('health-${widget.ownerId}'),
                      future: _health,
                      builder: (context, snapshot) => _ConnectionCard(
                        title: 'Salud del móvil',
                        icon: Icons.health_and_safety_outlined,
                        status: _healthStatus(snapshot),
                        description: _healthDescription(snapshot),
                        action: 'Historial y permisos',
                        onTap: () => _open(widget.onOpenHealth),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<GarminConnectionSnapshot>(
                      key: ValueKey('garmin-${widget.ownerId}'),
                      future: _garmin,
                      builder: (context, snapshot) => _ConnectionCard(
                        title: 'Garmin',
                        icon: Icons.watch_outlined,
                        status: _garminStatus(snapshot),
                        description: snapshot.hasError
                            ? 'No se pudo comprobar la conexión. Entra para revisar su estado o reinténtalo.'
                            : snapshot.data?.allowed == false
                            ? 'Puedes revisar o desconectar tu cuenta. La sincronización requiere Pro o un servicio de entrenador vigente.'
                            : 'Tu cuenta Garmin, las actividades, el envío de sesiones y la app del reloj.',
                        action: 'Gestionar Garmin',
                        onTap: () => _open(widget.onOpenGarmin),
                      ),
                    ),
                    if (widget.onOpenAppleWatch != null) ...[
                      _ConnectionCard(
                        title: 'Apple Watch',
                        icon: Icons.watch_outlined,
                        status: 'Carreras en Entreno',
                        description: 'Programa las carreras pautadas desde el iPhone emparejado. Requiere Pro o un servicio de entrenador vigente.',
                        action: 'Gestionar Apple Watch',
                        onTap: () => _open(widget.onOpenAppleWatch!),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _healthStatus(AsyncSnapshot<HealthStoreAvailability> snapshot) {
    if (snapshot.hasError) return 'Disponibilidad sin confirmar';
    if (snapshot.connectionState != ConnectionState.done) return 'Comprobando…';
    return switch (snapshot.data) {
      HealthStoreAvailability.available => 'Lectura disponible',
      HealthStoreAvailability.updateRequired => 'Necesita actualización',
      HealthStoreAvailability.notIntegrated => 'Lectura en preparación',
      HealthStoreAvailability.unavailable =>
        'No disponible en este dispositivo',
      _ => 'Lectura desde el móvil',
    };
  }

  String _healthDescription(AsyncSnapshot<HealthStoreAvailability> snapshot) {
    if (snapshot.hasError) {
      return 'No se pudo comprobar Salud. Puedes consultar tu historial o reintentar.';
    }
    return switch (snapshot.data) {
      HealthStoreAvailability.available =>
        'Importa carreras desde ${widget.health.platform == LocalHealthPlatform.appleHealth ? 'Salud de Apple' : 'Health Connect'}. Los permisos se revisan al leer.',
      HealthStoreAvailability.notIntegrated => 'La lectura de Health Connect está en preparación. Puedes consultar tus carreras guardadas.',
      HealthStoreAvailability.unavailable ||
      HealthStoreAvailability.updateRequired => 'Revisa la disponibilidad de Salud en el móvil. Tus carreras guardadas siguen en el historial.',
      HealthStoreAvailability.unsupported => 'Consulta tus carreras guardadas. Para leer Salud de Apple, usa EntrenaOP en el iPhone.',
      _ => 'Consulta e importa tus carreras al historial.',
    };
  }

  String _garminStatus(AsyncSnapshot<GarminConnectionSnapshot> snapshot) {
    if (snapshot.hasError) return 'Estado sin confirmar';
    if (snapshot.connectionState != ConnectionState.done) return 'Comprobando…';
    final connection = snapshot.data;
    if (connection == null) return 'Estado sin confirmar';
    if (!connection.allowed) return 'Sincronización no disponible';
    return switch (connection.status) {
      GarminConnectionStatus.disconnected => 'Sin conectar',
      GarminConnectionStatus.connected => 'Cuenta conectada',
      GarminConnectionStatus.authorizing => 'Autorización pendiente',
      GarminConnectionStatus.authorizationFailed => 'Requiere atención',
      GarminConnectionStatus.disconnecting => 'Desconectando',
      GarminConnectionStatus.revocationPending => 'Desconexión pendiente',
    };
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final String title, status, description, action;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            Text(
              action,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    ),
  );
}
