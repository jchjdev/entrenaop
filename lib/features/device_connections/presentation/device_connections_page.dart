import 'package:device_health/device_health.dart';
import 'package:flutter/material.dart';

import '../domain/garmin_connection.dart';
import 'device_watch_artwork.dart';

class DeviceConnectionsPage extends StatefulWidget {
  const DeviceConnectionsPage({
    super.key,
    required this.ownerId,
    required this.health,
    required this.garmin,
    required this.onOpenHealth,
    required this.onOpenGarmin,
    this.onOpenAppleWatch,
    this.showPlannedProviders = false,
  });

  final String ownerId;
  final bool showPlannedProviders;
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
                    Text(
                      'Conecta tu reloj',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tus sesiones y tus resultados, en un mismo lugar.',
                    ),
                    const SizedBox(height: 20),
                    _DeviceGrid(
                      children: [
                        FutureBuilder<GarminConnectionSnapshot>(
                          key: ValueKey('garmin-${widget.ownerId}'),
                          future: _garmin,
                          builder: (context, snapshot) => _DeviceTile(
                            title: 'Garmin',
                            accent: const Color(0xff69c6ff),
                            status: _garminStatus(snapshot),
                            connected:
                                snapshot.connectionState ==
                                    ConnectionState.done &&
                                !snapshot.hasError &&
                                snapshot.data?.status ==
                                    GarminConnectionStatus.connected,
                            description: snapshot.hasError
                                ? 'No se pudo comprobar la conexión. Entra para revisar su estado o reinténtalo.'
                                : snapshot.data?.allowed == false
                                ? 'Puedes revisar o desconectar tu cuenta. La sincronización requiere Pro o un servicio de entrenador vigente.'
                                : 'Tu cuenta Garmin, las actividades y el envío de sesiones.',
                            action: 'Gestionar Garmin',
                            onTap: () => _open(widget.onOpenGarmin),
                          ),
                        ),
                        if (widget.onOpenAppleWatch != null)
                          _DeviceTile(
                            title: 'Apple Watch',
                            accent: const Color(0xffff8a58),
                            square: true,
                            status: 'Carreras desde el iPhone',
                            description: 'Programa las carreras pautadas desde el iPhone emparejado. Requiere Pro o un servicio de entrenador vigente.',
                            action: 'Gestionar Apple Watch',
                            onTap: () => _open(widget.onOpenAppleWatch!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<HealthStoreAvailability>(
                      key: ValueKey('health-${widget.ownerId}'),
                      future: _health,
                      builder: (context, snapshot) => Tooltip(
                        message: _healthDescription(snapshot),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xffff6b88),
                              size: 32,
                            ),
                            title: const Text('Salud del móvil'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_healthStatus(snapshot)),
                                const Text('Historial y permisos'),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(widget.onOpenHealth),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showPlannedProviders) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text('Más marcas'),
                        subtitle: const Text('Conexiones en estudio'),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Huawei, Suunto, Amazfit, Polar y COROS todavía no se pueden conectar a EntrenaOP.',
                            ),
                          ),
                          _DeviceGrid(
                            children: [
                              for (final brand in _plannedBrands)
                                _DeviceTile(
                                  title: brand.name,
                                  accent: brand.color,
                                  status: 'En estudio',
                                  description: 'Esta conexión todavía no está disponible en EntrenaOP.',
                                  action: 'Ver información',
                                  onTap: () => _showPlannedBrand(brand.name),
                                ),
                            ],
                          ),
                        ],
                      ),
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

  void _showPlannedBrand(String name) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text('Conexión en estudio'),
              const SizedBox(height: 8),
              const Text(
                'Esta marca todavía no puede conectarse a EntrenaOP. Cuando esté disponible, podrás vincular tu cuenta desde aquí.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

const _plannedBrands = [
  (name: 'Huawei', color: Color(0xffef796b)),
  (name: 'Suunto', color: Color(0xffefaa61)),
  (name: 'Amazfit', color: Color(0xff79cfb3)),
  (name: 'Polar', color: Color(0xfff27294)),
  (name: 'COROS', color: Color(0xffc1b2ff)),
];

class _DeviceGrid extends StatelessWidget {
  const _DeviceGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(18) <= 25
          ? 2
          : 1;
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columns) ...[
            if (i > 0) const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  if (columns == 2) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: i + 1 < children.length
                          ? children[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.title,
    required this.accent,
    required this.status,
    required this.description,
    required this.action,
    required this.onTap,
    this.square = false,
    this.connected = false,
  });

  final String title, status, description, action;
  final Color accent;
  final bool square, connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: onTap,
    label: '$title. $status. $action',
    hint: description,
    excludeSemantics: true,
    child: Tooltip(
      message: description,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: connected
                ? accent.withValues(alpha: .55)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: Column(
              children: [
                DeviceWatchArtwork(accent: accent, square: square),
                const SizedBox(height: 2),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (connected) ...[
                      Icon(Icons.check_circle_rounded, size: 13, color: accent),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Spacer(),
                Text(
                  action,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
