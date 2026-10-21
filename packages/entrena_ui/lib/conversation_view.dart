import 'package:flutter/material.dart';

import 'src/workflow_exit_guard.dart';

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.mine,
    this.contextLabel,
  });
  final String id, body;
  final DateTime createdAt;
  final bool mine;
  final String? contextLabel;
}

class ConversationHeader {
  const ConversationHeader({required this.title, required this.canSend});
  final String title;
  final bool canSend;
}

/// Presentación compartida: identidad, acceso y persistencia se inyectan.
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.header,
    required this.load,
    required this.send,
    required this.newOperationId,
    required this.errorLabel,
  });
  final Future<ConversationHeader> Function() header;
  final Future<List<ConversationEntry>> Function(ConversationEntry? before)
  load;
  final Future<void> Function(String operationId, String body) send;
  final String Function() newOperationId;
  final String Function(Object error) errorLabel;
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _body = TextEditingController();
  List<ConversationEntry> _items = [];
  ConversationHeader? _header;
  bool _busy = true, _sending = false, _more = false;
  String? _error, _sendError, _operation, _pending;
  WorkflowExitController? _exit;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = WorkflowExitScope.maybeOf(context);
    if (next != _exit) {
      _exit?.onExit = null;
      _exit = next;
      _exit?.onExit = _requestExit;
    }
  }

  @override
  void dispose() {
    _exit?.onExit = null;
    _body.dispose();
    super.dispose();
  }

  Future<bool> _requestExit() async {
    if (_sending) return false;
    if (_body.text.trim().isEmpty && _pending == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Salir de la conversación?'),
            content: Text(
              _pending == null ? 'El mensaje todavía no se ha enviado.' : 'El envío no está confirmado. Al salir conservarás los mensajes ya recibidos, pero perderás este reintento.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir'),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final header = await widget.header();
      final rows = await widget.load(more ? _items.last : null);
      if (mounted) {
        setState(() {
          _header = header;
          _items = {
            for (final entry in more ? [..._items, ...rows] : rows)
              entry.id: entry,
          }.values.toList();
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = widget.errorLabel(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _busy || (_header?.canSend != true && _pending == null)) {
      return;
    }
    final text = _pending ?? _body.text.trim();
    if (text.isEmpty || text.length > 4000) return;
    setState(() {
      _sending = true;
      _sendError = null;
      _operation ??= widget.newOperationId();
      _pending ??= text;
    });
    try {
      await widget.send(_operation!, _pending!);
      if (!mounted) return;
      setState(() {
        _operation = null;
        _pending = null;
        _body.clear();
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _sendError = widget.errorLabel(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_header?.title ?? 'Conversación'),
      actions: [
        IconButton(
          onPressed: _busy || _sending ? null : _load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _load,
                child: const Text('Reintentar consulta'),
              ),
            ],
            if (_header?.canSend == false)
              const Text(
                'Conversación conservada en consulta. El servicio no admite nuevos envíos ahora.',
              ),
            if (_header?.canSend == true || _pending != null) ...[
              TextField(
                controller: _body,
                enabled: !_sending && _pending == null,
                maxLength: 4000,
                minLines: 2,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Mensaje para la preparación',
                ),
              ),
              if (_sendError != null) Text(_sendError!),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed:
                      _busy ||
                          _sending ||
                          (_pending ?? _body.text.trim()).isEmpty
                      ? null
                      : _send,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _pending == null
                        ? 'Enviar mensaje'
                        : 'Reintentar el mismo envío',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Mensajes más recientes primero. Actualiza para consultar respuestas.',
            ),
            if (!_busy && _items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay mensajes.'),
              ),
            for (final entry in _items)
              Align(
                alignment: entry.mine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.mine ? 'Tú' : 'Respuesta recibida',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (entry.contextLabel != null)
                          Text(entry.contextLabel!),
                        SelectableText(entry.body),
                        Text(
                          entry.createdAt.toLocal().toString().substring(0, 16),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_more)
              TextButton(
                onPressed: _busy || _sending ? null : () => _load(more: true),
                child: const Text('Cargar mensajes anteriores'),
              ),
          ],
        ),
      ),
    ),
  );
}
