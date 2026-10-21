import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import '../../guided_programs/domain/admin_guided_work.dart';
import '../data/admin_operations_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.operations,
    this.sessions,
    this.programs,
  });
  final AdminOperationsRepository operations;
  final WorkoutEditorWorkRepository? sessions;
  final AdminGuidedWorkRepository? programs;
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _refresh = 0;
  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  'Pendientes del admin',
                  style: MediaQuery.sizeOf(context).width < 600
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _refresh++),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar pendientes'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Retoma tu trabajo, revisa el catálogo y comprueba las copias. Guardar un trabajo incompleto no publica contenido.',
            ),
            const SizedBox(height: 20),
            AdminSessionWorkList(
              key: ValueKey('sessions-$_refresh'),
              repository: widget.sessions,
              onOpen: _open,
            ),
            if (widget.programs != null)
              _DashboardSection<List<GuidedWork>>(
                key: ValueKey('programs-$_refresh'),
                title: 'Programas por continuar',
                load: widget.programs!.list,
                builder: (items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (items.isEmpty)
                      const Text('No tienes programas incompletos.'),
                    for (final work in items.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(work.name),
                        subtitle: const Text(
                          'Trabajo incompleto · todavía fuera del catálogo',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _open('/guided-programs/work/${work.id}'),
                      ),
                    if (items.length > 5)
                      Text(
                        '${items.length} trabajos disponibles en Programas guiados.',
                      ),
                    TextButton(
                      onPressed: () => _open('/guided-programs'),
                      child: const Text('Ver programas guiados'),
                    ),
                  ],
                ),
              ),
            _DashboardSection<List<Map<String, dynamic>>>(
              key: ValueKey('quality-$_refresh'),
              title: 'Revisión del catálogo',
              load: widget.operations.quality,
              builder: (items) {
                final errors = items
                    .where((i) => i['severity'] == 'error')
                    .length;
                final attention = items
                    .where((i) => i['severity'] == 'attention')
                    .length;
                final pending = items
                    .where((i) => i['severity'] == 'pending')
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$errors ${errors == 1 ? "error" : "errores"} · $attention ${attention == 1 ? "aviso por completar" : "avisos por completar"} · $pending ${pending == 1 ? "pendiente editorial" : "pendientes editoriales"}',
                    ),
                    const Text(
                      'Un recurso puede tener varios avisos. Los borradores no son errores.',
                    ),
                    for (final issue in items.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(issue['name'] as String),
                        subtitle: Text(issue['message'] as String),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _open(adminQualityPath(issue)),
                      ),
                    TextButton(
                      onPressed: () => _open('/quality'),
                      child: const Text('Revisar todos los avisos'),
                    ),
                  ],
                );
              },
            ),
            _DashboardSection<Map<String, dynamic>>(
              key: ValueKey('diagnostics-$_refresh'),
              title: 'Copias y errores de desarrollo',
              load: widget.operations.diagnostics,
              builder: (data) {
                final backups = (data['backups'] as List).cast<Map>();
                final latest = backups.firstOrNull;
                final checked = DateTime.tryParse(
                  data['checked_at']?.toString() ?? '',
                );
                final expires = DateTime.tryParse(
                  latest?['expires_at']?.toString() ?? '',
                );
                final finished = DateTime.tryParse(
                  latest?['finished_at']?.toString() ?? '',
                );
                final verified =
                    latest?['status'] == 'verified' &&
                    checked != null &&
                    expires != null &&
                    expires.isAfter(checked);
                final fresh =
                    verified &&
                    finished != null &&
                    checked.difference(finished) < const Duration(hours: 36);
                final errors = data['errors'] as List;
                final collection = data['collection'] as Map?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      latest == null
                          ? 'Sin copia registrada'
                          : fresh
                          ? 'Copia cifrada verificada y disponible'
                          : verified
                          ? 'Copia disponible; comprobación desactualizada'
                          : 'Revisar la última copia: no hay disponibilidad verificada',
                    ),
                    if (latest?['restore_verified_at'] != null)
                      Text(
                        'Último ensayo de restauración: ${adminPendingDate(latest!['restore_verified_at'])}',
                      ),
                    Text(
                      '${errors.length}${errors.length >= 100 ? " o más" : ""} errores registrados en los últimos 14 días.',
                    ),
                    Text(
                      collection == null
                          ? 'Sin comprobación de recogida de servicios.'
                          : 'Última recogida: ${adminPendingDate(collection['checked_at'])} · ${collection['status'] == "success" ? "consulta completada" : "revisar recogida"}',
                    ),
                    if (collection?['truncated'] == true)
                      const Text('La recogida de servicios es parcial.'),
                    const Text(
                      'Los eventos de pruebas también pueden aparecer. El registro no garantiza la ausencia de otros errores.',
                    ),
                    TextButton(
                      onPressed: () => _open('/system'),
                      child: const Text('Revisar copias y registro de errores'),
                    ),
                  ],
                );
              },
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _open('/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('Historial editorial'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _open('/sessions'),
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: const Text('Catálogo de sesiones'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String adminPendingDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Sin comprobación';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String adminQualityPath(
  Map<String, dynamic> issue,
) => switch (issue['resource_type']) {
  'program' => '/guided-programs/${issue['resource_id']}/review',
  'session' =>
    issue['program_id'] == null
        ? '/sessions/${issue['resource_id']}'
        : '/programs/${Uri.encodeComponent(issue['program_id'] as String)}/sessions/${issue['resource_id']}',
  'exercise' => '/exercises?edit=${issue['resource_id']}',
  _ => '/quality',
};

class AdminSessionWorkList extends StatefulWidget {
  const AdminSessionWorkList({
    super.key,
    required this.repository,
    required this.onOpen,
    this.programId,
    this.limit = 5,
  });
  final WorkoutEditorWorkRepository? repository;
  final Future<void> Function(String) onOpen;
  final String? programId;
  final int limit;
  @override
  State<AdminSessionWorkList> createState() => _AdminSessionWorkListState();
}

class _AdminSessionWorkListState extends State<AdminSessionWorkList> {
  int _revision = 0;
  Future<void> _discard(WorkoutEditorWork work) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar este trabajo incompleto?'),
        content: Text(
          '«${work.name}» dejará de aparecer en los trabajos pendientes. Las sesiones guardadas se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar trabajando'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar trabajo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository!.discard(work);
      if (mounted) setState(() => _revision++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El trabajo ha cambiado o no se pudo confirmar. Actualiza antes de reintentar.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.repository == null
      ? const SizedBox.shrink()
      : _DashboardSection<List<WorkoutEditorWork>>(
          key: ValueKey(_revision),
          title: 'Sesiones por continuar',
          load: widget.repository!.list,
          builder: (all) {
            final items = all
                .where((w) => w.origin['programId'] == widget.programId)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  const Text(
                    'No tienes sesiones incompletas en esta consulta.',
                  ),
                if (all.length >= 100)
                  const Text(
                    'Se consultan hasta 100 trabajos recientes; el listado puede ser parcial.',
                  ),
                for (final work in items.take(widget.limit))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(work.name),
                    subtitle: Text(
                      work.origin['parentWorkId'] != null
                          ? 'Continuar dentro de su programa'
                          : work.state['intent'] != null
                          ? 'Guardado final pendiente de confirmar'
                          : 'Formulario incompleto · no publicado',
                    ),
                    trailing: work.origin['parentWorkId'] != null
                        ? const Icon(Icons.arrow_forward)
                        : IconButton(
                            tooltip: 'Descartar trabajo incompleto',
                            onPressed: () => _discard(work),
                            icon: const Icon(Icons.delete_outline),
                          ),
                    onTap: () => widget.onOpen(
                      work.origin['parentWorkId'] != null
                          ? '/guided-programs/work/${work.origin['parentWorkId']}'
                          : '${widget.programId == null ? "/sessions" : "/programs/${Uri.encodeComponent(widget.programId!)}/sessions"}/work/${work.id}',
                    ),
                  ),
                if (items.length > widget.limit)
                  Text(
                    '${items.length} trabajos en esta consulta. Se muestran los ${widget.limit} más recientes.',
                  ),
                if (items.length > widget.limit)
                  TextButton(
                    onPressed: () => widget.onOpen(
                      widget.programId == null
                          ? '/sessions'
                          : '/programs/${Uri.encodeComponent(widget.programId!)}/sessions',
                    ),
                    child: const Text('Ver los trabajos de sesiones'),
                  ),
              ],
            );
          },
        );
}

class _DashboardSection<T> extends StatefulWidget {
  const _DashboardSection({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
  });
  final String title;
  final Future<T> Function() load;
  final Widget Function(T) builder;
  @override
  State<_DashboardSection<T>> createState() => _DashboardSectionState<T>();
}

class _DashboardSectionState<T> extends State<_DashboardSection<T>> {
  late Future<T> _data = widget.load();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<T>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No se pudo comprobar esta sección. Su estado es desconocido.',
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _data = widget.load();
                      }),
                      child: const Text('Reintentar sección'),
                    ),
                  ],
                );
              }
              return widget.builder(snapshot.data as T);
            },
          ),
        ],
      ),
    ),
  );
}
