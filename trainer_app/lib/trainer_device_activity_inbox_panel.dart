import 'package:flutter/material.dart';
import 'package:workout_core/device_activity_inbox.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_editor_ui/device_activity_summary_card.dart';

class TrainerDeviceActivityInboxPanel extends StatefulWidget {
  const TrainerDeviceActivityInboxPanel({super.key, required this.repository});
  final DeviceActivityInboxRepository repository;

  @override
  State<TrainerDeviceActivityInboxPanel> createState() => _InboxState();
}

class _InboxState extends State<TrainerDeviceActivityInboxPanel> {
  Future<List<DeviceActivitySummary>>? _results;

  void _load() => setState(() {
    _results = widget.repository.load();
  });

  @override
  void didUpdateWidget(covariant TrainerDeviceActivityInboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _results = _results == null ? null : widget.repository.load();
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('my-received-device-activities'),
      leading: const Icon(Icons.watch_outlined),
      title: const Text('Mis actividades recibidas'),
      subtitle: const Text('Garmin · Pendientes de incorporar al historial'),
      onExpansionChanged: (open) {
        if (open && _results == null) _load();
      },
      childrenPadding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Últimas 30 actividades de tu cuenta sin confirmar. Algunas ya tienen la pauta identificada y necesitan revisión; otras requieren elegir una sesión. Puedes revisarlas en la app del deportista, en Garmin → Actividades recibidas.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar actividades recibidas'),
          ),
        ),
        if (_results case final results?)
          FutureBuilder<List<DeviceActivitySummary>>(
            // Un cambio de cuenta/repositorio nunca conserva datos anteriores.
            key: ObjectKey(results),
            future: results,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return const Text(
                  'No se pudieron consultar las actividades. Pulsa Actualizar para volver a intentarlo.',
                );
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) {
                return const Text(
                  'No hay actividades recibidas pendientes de incorporar.',
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    DeviceActivitySummaryCard(result: row, showName: true),
                ],
              );
            },
          ),
      ],
    ),
  );
}
