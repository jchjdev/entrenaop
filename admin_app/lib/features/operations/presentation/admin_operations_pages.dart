import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/catalog_search.dart';

import '../../../core/app_config.dart';
import '../../guided_programs/domain/admin_guided_work.dart';
import '../data/admin_operations_repository.dart';
import 'admin_editorial_diff.dart';

String resourceLabel(Object? kind) => switch (kind) {
  'session' => 'Sesión',
  'program' => 'Programa',
  'exercise' => 'Ejercicio',
  'warmup' => 'Calentamiento',
  'video' => 'Vídeo',
  _ => 'Contenido',
};
String operationDate(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return 'Fecha no disponible';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class AdminHistoryPage extends StatefulWidget {
  const AdminHistoryPage({super.key, required this.repository});
  final AdminOperationsRepository repository;
  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage> {
  List<Map<String, dynamic>> _items = [];
  String? _kind, _error;
  bool _loading = false, _hasMore = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.history(
        kind: _kind,
        beforeId: more && _items.isNotEmpty ? _items.last['id'] as int : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = more ? [..._items, ...rows] : rows;
        _hasMore = rows.length == 50;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'No se pudo cargar el historial. Reintenta.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial editorial')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Cambios registrados desde la activación del historial. Recuperar crea un borrador independiente y conserva el contenido actual.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (kind, label) in <(String?, String)>[
              (null, 'Todo'),
              ('session', 'Sesiones'),
              ('program', 'Programas'),
              ('warmup', 'Calentamientos'),
              ('exercise', 'Ejercicios'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _kind == kind,
                onSelected: _loading
                    ? null
                    : (_) {
                        setState(() {
                          _kind = kind;
                          _items = [];
                        });
                        _load();
                      },
              ),
          ],
        ),
        if (_error != null) _Retry(message: _error!, onRetry: _load),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading && _error == null && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Todavía no hay cambios registrados.'),
          ),
        for (final row in _items)
          Card(
            child: ListTile(
              title: Text(row['name'] as String),
              subtitle: Text(
                '${resourceLabel(row['resource_type'])} · ${operationDate(row['occurred_at'])}\n${switch (row['action']) {
                  'created' => 'Creado',
                  'removed' => 'Retirado o eliminado',
                  _ => 'Modificado',
                }}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/history/${row['id']}'),
            ),
          ),
        if (_hasMore)
          OutlinedButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Cargar cambios anteriores'),
          ),
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Actualizar historial'),
        ),
      ],
    ),
  );
}

class AdminHistoryDetailPage extends StatefulWidget {
  const AdminHistoryDetailPage({
    super.key,
    required this.repository,
    required this.eventId,
  });
  final AdminOperationsRepository repository;
  final int eventId;
  @override
  State<AdminHistoryDetailPage> createState() => _AdminHistoryDetailPageState();
}

class _AdminHistoryDetailPageState extends State<AdminHistoryDetailPage> {
  late Future<Map<String, dynamic>?> _event = widget.repository.event(
    widget.eventId,
  );
  bool _busy = false, _before = false;
  String? _request, _error, _restored;
  Future<void> _restore(Map<String, dynamic> event) async {
    if (_busy || _restored != null) return;
    final useBefore = event['after'] == null || _before;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => EntrenaDialog(
        title: const Text('Recuperar como borrador'),
        content: const Text(
          'Se creará un borrador independiente del estado seleccionado. No se publicará ni sustituirá el contenido actual. Las referencias deben seguir disponibles.',
        ),
        actions: [
          EntrenaDialogActions(
            primaryLabel: 'Cancelar',
            onPrimary: () => Navigator.pop(ctx, false),
            secondary: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crear borrador'),
              ),
            ],
          ),
        ],
      ),
    );
    if (yes != true || !mounted || _busy || _restored != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _request ??= newGuidedWorkId();
    try {
      final id = await widget.repository.restore(
        widget.eventId,
        _request!,
        useBefore: useBefore,
      );
      if (mounted) setState(() => _restored = id);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _error = ['22023', 'P0002', '42501'].contains(error.code)
              ? error.message
              : 'No se pudo confirmar la recuperación. Reintenta el mismo estado.';
          if (['22023', 'P0002', '42501'].contains(error.code)) {
            _request = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar la recuperación. Conserva esta pantalla y reintenta el mismo estado; no se duplicará. ',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sessionRestoredPath(Map<String, dynamic> event) {
    final data =
        event[event['after'] == null || _before ? 'before' : 'after'] as Map;
    if (data['catalog_scope'] == 'program' && data['program_id'] is String) {
      return '/programs/${Uri.encodeComponent(data['program_id'] as String)}/sessions/$_restored';
    }
    return '/sessions/$_restored';
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _request != null && _restored == null,
    isBusy: () => _busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Comparar cambios')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _event,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Retry(
              message: 'No se pudo cargar este cambio.',
              onRetry: () => setState(() {
                _event = widget.repository.event(widget.eventId);
              }),
            );
          }
          final event = snapshot.data!;
          final diffs = editorialDifferences(event['before'], event['after']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${resourceLabel(event['resource_type'])} · ${operationDate(event['occurred_at'])}',
              ),
              const SizedBox(height: 16),
              if (['session', 'program'].contains(event['resource_type'])) ...[
                if (event['before'] != null && event['after'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (before, label) in [
                        (true, 'Estado anterior'),
                        (false, 'Estado posterior'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _before == before,
                          onSelected: _busy || _request != null
                              ? null
                              : (_) => setState(() => _before = before),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_restored == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _restore(event),
                    icon: const Icon(Icons.restore),
                    label: Text(
                      _busy ? 'Recuperando…' : 'Recuperar como borrador',
                    ),
                  )
                else ...[
                  const Text('Borrador independiente recuperado.'),
                  FilledButton(
                    onPressed: () => context.push(
                      event['resource_type'] == 'program'
                          ? '/guided-programs/$_restored/review'
                          : _sessionRestoredPath(event),
                    ),
                    child: const Text('Abrir borrador recuperado'),
                  ),
                ],
              ] else
                const Text(
                  'Este recurso permite consultar los cambios. La recuperación como borrador corresponde a sesiones y programas.',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!),
                ),
              const SizedBox(height: 16),
              const Text(
                'Antes → Después',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (diffs.length == 200)
                const Text('Se muestran los primeros 200 campos modificados.'),
              for (final diff in diffs)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          diff.path,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText('Antes: ${diff.before}'),
                        const SizedBox(height: 8),
                        SelectableText('Después: ${diff.after}'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class AdminQualityPage extends StatefulWidget {
  const AdminQualityPage({super.key, required this.repository});
  final AdminOperationsRepository repository;
  @override
  State<AdminQualityPage> createState() => _AdminQualityPageState();
}

class _AdminQualityPageState extends State<AdminQualityPage> {
  late Future<List<Map<String, dynamic>>> _load = widget.repository.quality();
  String _filter = 'all', _query = '';
  void _refresh() => setState(() {
    _load = widget.repository.quality();
  });
  String _path(Map<String, dynamic> issue) => switch (issue['resource_type']) {
    'program' => '/guided-programs/${issue['resource_id']}/review',
    'session' =>
      issue['program_id'] == null
          ? '/sessions/${issue['resource_id']}'
          : '/programs/${Uri.encodeComponent(issue['program_id'] as String)}/sessions/${issue['resource_id']}',
    'exercise' => '/exercises?edit=${issue['resource_id']}',
    _ => '/exercises',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calidad del catálogo'),
      actions: [
        IconButton(
          tooltip: 'Actualizar calidad',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Retry(
            message: 'No se pudo revisar el catálogo.',
            onRetry: _refresh,
          );
        }
        final all = snapshot.data!;
        final visible = all
            .where(
              (r) =>
                  (_filter == 'all' || r['severity'] == _filter) &&
                  matchesCatalogSearch(_query, [
                    r['name'] as String,
                    r['message'] as String,
                  ]),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Revisión de datos guardados. Los borradores son tareas pendientes. Vídeos: último estado registrado.',
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                labelText: 'Buscar recurso o problema',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (code, label) in [
                  ('all', 'Todo'),
                  ('error', 'Errores'),
                  ('attention', 'Por completar'),
                  ('pending', 'Pendientes'),
                ])
                  ChoiceChip(
                    selected: _filter == code,
                    onSelected: (_) => setState(() => _filter = code),
                    label: Text(
                      '$label (${code == 'all' ? all.length : all.where((r) => r['severity'] == code).length})',
                    ),
                  ),
              ],
            ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay avisos con este filtro.'),
              ),
            for (final row in visible)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${resourceLabel(row['resource_type'])} · ${row['name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(row['message'] as String),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(_path(row)),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            row['resource_type'] == 'video'
                                ? 'Abrir ejercicios'
                                : 'Abrir recurso',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class AdminSystemPage extends StatefulWidget {
  const AdminSystemPage({super.key, required this.repository});
  final AdminOperationsRepository repository;
  @override
  State<AdminSystemPage> createState() => _AdminSystemPageState();
}

class _AdminSystemPageState extends State<AdminSystemPage> {
  late Future<Map<String, dynamic>> _status = widget.repository.status();
  late Future<Map<String, dynamic>?> _deployment = widget.repository
      .deployment();
  void _refresh() => setState(() {
    _status = widget.repository.status();
    _deployment = widget.repository.deployment();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Estado del sistema'),
      actions: [
        IconButton(
          tooltip: 'Comprobar estado',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Entorno compilado: ${AppConfig.isDevelopment ? 'Desarrollo' : 'Producción'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        FutureBuilder<Map<String, dynamic>?>(
          future: _deployment,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Text('Consultando versión desplegada…');
            }
            if (snapshot.hasError) {
              return const Text(
                'No se pudo comprobar el manifiesto de despliegue.',
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Text(
                'Compilación local sin manifiesto de despliegue.',
              );
            }
            final mismatch =
                (data['environment'] == 'development') !=
                    AppConfig.isDevelopment ||
                !AppConfig.supabaseUrl.contains(
                  data['supabaseProject']?.toString() ??
                      'proyecto-no-disponible',
                );
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      mismatch
                          ? 'La configuración del manifiesto no coincide con esta app.'
                          : 'Versión activa comprobada',
                    ),
                    SelectableText('Revisión: ${data['revision']}'),
                    Text('Compilada: ${operationDate(data['builtAtUtc'])}'),
                    SelectableText('Versión: ${data['releaseId']}'),
                  ],
                ),
              ),
            );
          },
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _status,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Text('Comprobando conexión…');
            }
            if (snapshot.hasError) {
              return _Retry(
                message: 'No se pudo comprobar la conexión al servidor.',
                onRetry: _refresh,
              );
            }
            final data = snapshot.data!;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Servidor accesible · ${operationDate(data['checked_at'])}',
                    ),
                    Text(
                      'Cambios editoriales registrados: ${data['history_events']}',
                    ),
                    Text(
                      'Vídeos con fallo registrado: ${data['failed_videos']}',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Copias de seguridad: sin verificar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Pendiente conectar el estado del proveedor y registrar una prueba de recuperación.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Registro general de errores de servicios: sin conectar. La conexión anterior es una comprobación puntual.',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class AdminAccountSupport extends StatefulWidget {
  const AdminAccountSupport({
    super.key,
    required this.repository,
    required this.userId,
  });
  final AdminOperationsRepository repository;
  final String userId;
  @override
  State<AdminAccountSupport> createState() => _AdminAccountSupportState();
}

class _AdminAccountSupportState extends State<AdminAccountSupport> {
  Future<Map<String, dynamic>>? _support;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Diagnóstico de acceso y programas'),
    subtitle: const Text('Consulta de soporte · no modifica la cuenta'),
    onExpansionChanged: (open) {
      if (open && _support == null) {
        setState(() {
          _support = widget.repository.support(widget.userId);
        });
      }
    },
    children: [
      if (_support != null)
        FutureBuilder<Map<String, dynamic>>(
          future: _support,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return _Retry(
                message: 'No se pudo cargar el diagnóstico o falta el permiso de cuentas.',
                onRetry: () => setState(() {
                  _support = widget.repository.support(widget.userId);
                }),
              );
            }
            final data = snapshot.data!;
            final programs = (data['programs'] as List).cast<Map>();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Comprobado: ${operationDate(data['checked_at'])}'),
                  Text(
                    'Último inicio de sesión: ${operationDate(data['last_sign_in_at'])}',
                  ),
                  if (programs.isEmpty)
                    const Text('No hay programas guiados seguidos.'),
                  if (programs.length == 50)
                    const Text(
                      'Se muestran los 50 seguimientos más recientes.',
                    ),
                  for (final p in programs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${p['name']} · v${p['version']}'),
                      subtitle: Text(
                        '${switch (p['state']) {
                          'active' => 'En curso',
                          'paused' => 'Pausado',
                          'completed' => 'Completado',
                          _ => 'Abandonado',
                        }} · fase ${(p['phase_index'] as num) + 1}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/guided-programs/${p['id']}/review'),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _support = widget.repository.support(widget.userId);
                    }),
                    child: const Text('Actualizar diagnóstico'),
                  ),
                ],
              ),
            );
          },
        ),
    ],
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
