import 'package:flutter/material.dart';

import '../data/admin_operations_repository.dart';
import 'operations_link.dart';

const _workflow =
    'https://github.com/jchjdev/entrenaop/actions/workflows/dev-operations.yml';
const _provider =
    'https://supabase.com/dashboard/project/sxbxfjqgoddzhtcyhalw/logs/explorer';

String _date(Object? raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (value == null) return 'Sin comprobación';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
}

class AdminRecoveryPanel extends StatefulWidget {
  const AdminRecoveryPanel({
    super.key,
    required this.repository,
    this.openUrl = openOperationsUrl,
  });
  final AdminOperationsRepository repository;
  final void Function(String) openUrl;
  @override
  State<AdminRecoveryPanel> createState() => _AdminRecoveryPanelState();
}

class _AdminRecoveryPanelState extends State<AdminRecoveryPanel> {
  late Future<Map<String, dynamic>> _data = widget.repository.diagnostics();
  String _filter = 'all';
  void _refresh() => setState(() {
    _data = widget.repository.diagnostics();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'No se pudieron comprobar las copias y los errores.',
                ),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Reintentar diagnóstico'),
                ),
              ],
            ),
          ),
        );
      }
      final rows = (snapshot.data!['backups'] as List).cast<Map>();
      final collection = snapshot.data!['collection'] as Map?;
      final events = (snapshot.data!['errors'] as List).cast<Map>();
      final checked = DateTime.parse(snapshot.data!['checked_at'] as String);
      final latest = rows.firstOrNull;
      final expires = DateTime.tryParse(
        latest?['expires_at']?.toString() ?? '',
      );
      final finished = DateTime.tryParse(
        latest?['finished_at']?.toString() ?? '',
      );
      final available =
          latest?['status'] == 'verified' &&
          expires != null &&
          expires.isAfter(checked);
      final fresh =
          available &&
          finished != null &&
          checked.difference(finished) < const Duration(hours: 36);
      final collectedAt = DateTime.tryParse(
        collection?['checked_at']?.toString() ?? '',
      );
      final logsFresh =
          collection?['status'] == 'success' &&
          collectedAt != null &&
          checked.difference(collectedAt) < const Duration(hours: 2);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Copias de seguridad',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    latest == null
                        ? 'Sin copia verificada todavía'
                        : fresh
                        ? 'Copia cifrada disponible · datos restaurados en ensayo aislado'
                        : available
                        ? 'Copia disponible; la última comprobación ya no es reciente'
                        : latest['status'] == 'failed'
                        ? 'La última copia ha fallado'
                        : latest['status'] == 'running'
                        ? 'Copia en curso'
                        : 'La copia registrada ha caducado',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Base de datos y archivos de Storage. Retención de 7 días. Vídeos externos y secretos de proveedores requieren recuperación aparte.',
                  ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_date(row['started_at'])} · ${switch (row['status']) {
                              'verified' => 'Verificada',
                              'running' => 'En curso',
                              _ => 'Fallida',
                            }}',
                          ),
                          if (row['restore_verified_at'] != null)
                            Text(
                              'Ensayo de datos y archivos: ${_date(row['restore_verified_at'])}',
                            ),
                          if (row['expires_at'] != null)
                            Text('Caduca: ${_date(row['expires_at'])}'),
                          if (RegExp(r'^[0-9]+-[0-9]+$')
                              .hasMatch(row['run_id']?.toString() ?? ''))
                            TextButton.icon(
                              onPressed: () => widget.openUrl(
                                'https://github.com/jchjdev/entrenaop/actions/runs/${(row['run_id'] as String).split('-').first}',
                              ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text(
                                'Ver ejecución y paquete cifrado',
                              ),
                            ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => widget.openUrl(_workflow),
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Abrir copias en GitHub'),
                  ),
                  const Text(
                    'Para crear otra copia, ejecuta allí el trabajo con copia activada. Restaurar sobre Dev requiere revisar el paquete y el destino; esta pantalla no sobrescribe tus datos.',
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registro de errores',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    collection == null
                        ? 'Recogida de servicios sin activar'
                        : logsFresh
                        ? 'Servicios consultados: ${_date(collection['checked_at'])}'
                        : 'Recogida de servicios pendiente o desactualizada: ${_date(collection['checked_at'])}',
                  ),
                  if (collection?['truncated'] == true)
                    const Text(
                      'Se alcanzó el límite de la consulta. El registro mostrado es parcial.',
                    ),
                  const Text(
                    'Código, servicio y fecha; sin mensajes, contraseñas ni contenido de formularios. Los errores controlados de pruebas también pueden aparecer. Se muestran hasta 100 eventos de los últimos 14 días.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (code, label) in [
                        ('all', 'Todos'),
                        ('admin', 'Admin'),
                        ('services', 'Servicios'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == code,
                          onSelected: (_) => setState(() => _filter = code),
                        ),
                    ],
                  ),
                  for (final event in events.where(
                    (e) =>
                        _filter == 'all' ||
                        (_filter == 'admin'
                            ? e['source'] == 'admin'
                            : e['source'] != 'admin'),
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${_date(event['occurred_at'])} · ${event['component']} · ${event['code']}',
                      ),
                    ),
                  if (events.isEmpty)
                    const Text(
                      'No hay errores registrados en esta ventana. Comprueba la fecha de recogida antes de concluir que no hubo fallos.',
                    ),
                  TextButton.icon(
                    onPressed: () => widget.openUrl(_provider),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Investigar en Supabase'),
                  ),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Actualizar copias y errores'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
