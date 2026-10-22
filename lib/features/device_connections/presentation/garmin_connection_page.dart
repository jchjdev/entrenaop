import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/garmin_connection.dart';
import 'garmin_connection_cubit.dart';

class GarminConnectionPage extends StatefulWidget {
  const GarminConnectionPage({
    super.key,
    required this.repository,
    required this.openAuthorization,
    required this.onOpenPro,
    this.onOpenTraining,
  });
  final GarminConnectionRepository repository;
  final Future<bool> Function(Uri) openAuthorization;
  final VoidCallback onOpenPro;
  final VoidCallback? onOpenTraining;
  @override
  State<GarminConnectionPage> createState() => _GarminConnectionPageState();
}

class _GarminConnectionPageState extends State<GarminConnectionPage>
    with WidgetsBindingObserver {
  late final GarminConnectionCubit cubit = GarminConnectionCubit(
    widget.repository,
  )..load();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) cubit.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cubit.close();
    super.dispose();
  }

  Future<void> _authorize() async {
    await cubit.begin();
    if (!mounted) return;
    final uri = cubit.state.authorizationUrl;
    if (uri == null) return;
    bool opened;
    try {
      opened = await widget.openAuthorization(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir Garmin. Cancela el intento y vuelve a probar.',
          ),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar Garmin'),
        content: const Text(
          'Se detendrá la conexión y se solicitará retirar el acceso en Garmin. Tu historial se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await cubit.disconnect();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conexión con Garmin')),
    body: BlocBuilder<GarminConnectionCubit, GarminConnectionState>(
      bloc: cubit,
      builder: (context, state) {
        final snapshot = state.snapshot;
        final status = snapshot?.status;
        final pending =
            status == GarminConnectionStatus.disconnecting ||
            status == GarminConnectionStatus.revocationPending;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Garmin Connect',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Autoriza tu cuenta Garmin para vincularla a tu cuenta EntrenaOP. Tú eliges los permisos en Garmin.',
            ),
            const SizedBox(height: 16),
            if (state.busy) const LinearProgressIndicator(),
            if (state.problem != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(switch (state.problem!) {
                  GarminConnectionProblem.accountChanged =>
                    'La sesión ha cambiado. Vuelve a abrir esta pantalla.',
                  GarminConnectionProblem.accessRequired => 'La conexión directa requiere Pro o un servicio de entrenador vigente.',
                  GarminConnectionProblem.conflict => 'La conexión ha cambiado. Actualiza su estado antes de continuar.',
                  GarminConnectionProblem.rateLimited =>
                    'Espera unos segundos antes de volver a autorizar.',
                  GarminConnectionProblem.invalidResponse ||
                  GarminConnectionProblem.unavailable => 'No se pudo consultar o cambiar la conexión. Prueba de nuevo más tarde.',
                }),
              ),
            if (snapshot != null) ...[
              Text(switch (status!) {
                GarminConnectionStatus.disconnected => 'Sin conexión',
                GarminConnectionStatus.authorizing => 'Autorización pendiente',
                GarminConnectionStatus.connected => 'Cuenta conectada',
                GarminConnectionStatus.authorizationFailed =>
                  'No se completó la autorización',
                GarminConnectionStatus.disconnecting =>
                  'Desconectando de Garmin',
                GarminConnectionStatus.revocationPending => 'Conexión detenida. Revocación en Garmin pendiente de confirmar.',
              }, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (status == GarminConnectionStatus.connected) ...[
                Text(
                  snapshot.canRead
                      ? 'Lectura de actividades autorizada.'
                      : 'No has autorizado la lectura de actividades.',
                ),
                Text(
                  snapshot.canSend
                      ? 'Permiso para enviar sesiones concedido.'
                      : 'No has autorizado el envío de sesiones.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Desde aquí puedes consultar los permisos y desconectar tu cuenta.',
                ),
                if (snapshot.allowed &&
                    snapshot.canSend &&
                    widget.onOpenTraining != null)
                  FilledButton.icon(
                    onPressed: state.busy ? null : widget.onOpenTraining,
                    icon: const Icon(Icons.watch),
                    label: const Text('Enviar una carrera'),
                  ),
              ],
              if (!snapshot.allowed) ...[
                const Text(
                  'La conexión directa con Garmin está incluida en Pro o en tu servicio de entrenador vigente. Salud sigue disponible para todos.',
                ),
                TextButton(
                  onPressed: state.busy ? null : widget.onOpenPro,
                  child: const Text('Ver Pro'),
                ),
              ],
              if (snapshot.allowed &&
                  (status == GarminConnectionStatus.disconnected ||
                      status == GarminConnectionStatus.authorizationFailed))
                FilledButton(
                  onPressed: state.busy ? null : _authorize,
                  child: const Text('Conectar Garmin'),
                ),
              if (status == GarminConnectionStatus.authorizing)
                const Text(
                  'Completa la autorización en Garmin y vuelve aquí. Si el intento ha caducado, cancélalo antes de empezar otro.',
                ),
              if (status == GarminConnectionStatus.connected ||
                  status == GarminConnectionStatus.authorizing ||
                  pending)
                OutlinedButton(
                  onPressed: state.busy ? null : _disconnect,
                  child: Text(
                    pending
                        ? 'Reintentar desconexión'
                        : status == GarminConnectionStatus.authorizing
                        ? 'Cancelar conexión'
                        : 'Desconectar Garmin',
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: state.busy ? null : cubit.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar estado'),
            ),
          ],
        );
      },
    ),
  );
}
