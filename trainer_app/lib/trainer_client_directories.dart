import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_client_workspace_repository.dart';

class TrainerClientConversationRoute extends StatefulWidget {
  const TrainerClientConversationRoute({
    super.key,
    required this.repository,
    required this.clientId,
    required this.conversation,
  });
  final TrainerClientWorkspaceRepository repository;
  final String clientId;
  final Widget Function(String relationId) conversation;
  @override
  State<TrainerClientConversationRoute> createState() =>
      _TrainerClientConversationRouteState();
}

class _TrainerClientConversationRouteState
    extends State<TrainerClientConversationRoute> {
  late Future<TrainerClientWorkspace> _future = widget.repository.get(
    widget.clientId,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<TrainerClientWorkspace>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(
              () => _future = widget.repository.get(widget.clientId),
            ),
            child: Text('${trainerError(snapshot.error!)} Reintentar'),
          ),
        );
      }
      final workspace = snapshot.data!;
      final relationId =
          workspace.client.activeRelationId ??
          workspace.relations.firstOrNull?['id'] as String?;
      if (relationId == null) {
        return const Center(
          child: Text('No hay una etapa del servicio con conversación.'),
        );
      }
      return widget.conversation(relationId);
    },
  );
}

/// Acceso directo a las fichas autorizadas, sin consultar conversaciones ajenas.
class TrainerClientDirectoryPage extends StatefulWidget {
  const TrainerClientDirectoryPage({
    super.key,
    required this.repository,
    required this.reports,
  });
  final TrainerRepository repository;
  final bool reports;
  @override
  State<TrainerClientDirectoryPage> createState() =>
      _TrainerClientDirectoryPageState();
}

class _TrainerClientDirectoryPageState
    extends State<TrainerClientDirectoryPage> {
  List<TrainerClient> _items = [];
  bool _busy = true, _more = false;
  String? _error;
  String _search = '';
  TrainerClientState _state = TrainerClientState.active;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.clients(
        state: _state,
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.reports ? 'Informes y evolución' : 'Conversaciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.reports
              ? 'Elige un alumno para consultar su evolución y exportar su informe.'
              : 'Elige un alumno para abrir la conversación de tu servicio.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in TrainerClientState.values)
              ChoiceChip(
                label: Text(switch (state) {
                  TrainerClientState.active => 'Activos',
                  TrainerClientState.inactive => 'Inactivos',
                  TrainerClientState.archived => 'Archivados',
                }),
                selected: _state == state,
                onSelected: _busy
                    ? null
                    : (_) {
                        setState(() {
                          _state = state;
                          _items = [];
                        });
                        _load();
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar entre los alumnos cargados',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Reintentar')),
        if (!_busy && _error == null && _items.isEmpty)
          const Text('No hay alumnos en este estado.'),
        ProfessionalCatalogGrid(
          children: [
            for (final client in _items.where(
              (c) => c.name.toLowerCase().contains(_search.toLowerCase()),
            ))
              Card(
                child: ListTile(
                  leading: Icon(
                    widget.reports ? Icons.insights : Icons.chat_bubble_outline,
                  ),
                  title: Text(client.name),
                  subtitle: Text(
                    widget.reports
                        ? 'Evolución y exportación del servicio'
                        : client.active
                        ? 'Conversación activa'
                        : 'Historial de conversación',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => context.go(
                          '/clients/${client.personId}${widget.reports ? '?area=progress' : '/conversation'}',
                        ),
                ),
              ),
          ],
        ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más alumnos'),
          ),
      ],
    ),
  );
}
