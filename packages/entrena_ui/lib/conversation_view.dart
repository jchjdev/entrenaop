import 'dart:async';

import 'src/professional_workspace.dart';

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
  const ConversationHeader({
    required this.title,
    required this.canSend,
    this.notice,
    this.readOnlyMessage,
    this.actions,
  });
  final String title;
  final bool canSend;
  final String? notice, readOnlyMessage;
  final List<Widget> Function(Future<void> Function() refresh)? actions;
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
    this.refreshInterval,
    this.onDisplayed,
    this.messageLabel = 'Mensaje para la preparación',
  });
  final Future<ConversationHeader> Function() header;
  final Future<List<ConversationEntry>> Function(ConversationEntry? before)
  load;
  final Future<void> Function(String operationId, String body) send;
  final String Function() newOperationId;
  final String Function(Object error) errorLabel;
  final Duration? refreshInterval;
  final Future<void> Function(List<ConversationEntry> entries)? onDisplayed;
  final String messageLabel;
  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView>
    with WidgetsBindingObserver {
  final _body = TextEditingController();
  final _scroll = ScrollController();
  bool _loaded = false, _newMessages = false;
  List<ConversationEntry> _items = [];
  ConversationHeader? _header;
  bool _busy = true, _sending = false, _more = false;
  String? _error, _sendError, _operation, _pending;
  WorkflowExitController? _exit;
  Timer? _timer;
  Completer<void>? _loading;
  bool get _visible =>
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final interval = widget.refreshInterval;
    if (interval != null && interval > Duration.zero) {
      _timer = Timer.periodic(interval, (_) {
        if (mounted && _visible && !_sending && _loading == null) {
          _load(quiet: true);
        }
      });
    }
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
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _exit?.onExit = null;
    _scroll.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.refreshInterval != null &&
        mounted &&
        _visible &&
        !_sending) {
      _load(quiet: true);
    }
  }

  Future<void> _load({bool more = false, bool quiet = false}) async {
    while (_loading != null) {
      if (quiet) return;
      await _loading!.future;
      if (!mounted) return;
    }
    var pixels = 0.0, extent = 0.0;
    var stick = false, updated = false;
    final completion = Completer<void>();
    _loading = completion;
    if (!quiet) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final header = await widget.header();
      final rows = await widget.load(
        more && _items.isNotEmpty ? _items.last : null,
      );
      if (!mounted) return;
      final position = _scroll.hasClients ? _scroll.position : null;
      pixels = position?.pixels ?? 0.0;
      extent = position?.maxScrollExtent ?? 0.0;
      stick =
          !more &&
          (!_loaded || !quiet || _sending || (position?.extentAfter ?? 0) < 80);
      updated = true;
      setState(() {
        final incoming = rows.any(
          (row) => !_items.any((old) => old.id == row.id),
        );
        if (quiet && !stick && incoming) _newMessages = true;
        if (stick) _newMessages = false;
        _loaded = true;
        _header = header;
        _error = null;
        // Si llegaron más de una página, reinicia el cursor para no ocultar el hueco.
        final overlaps = rows.any((r) => _items.any((old) => old.id == r.id));
        final retain = more || (quiet && (rows.length < 50 || overlaps));
        _items =
            {
              for (final entry in retain ? [..._items, ...rows] : rows)
                entry.id: entry,
            }.values.toList()..sort((a, b) {
              final date = b.createdAt.compareTo(a.createdAt);
              return date != 0 ? date : b.id.compareTo(a.id);
            });
        if (more || !retain) _more = rows.length == 50;
      });
      // Se acredita solo la página recibida y presentada; nunca los envíos concurrentes.
      if (widget.onDisplayed != null) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && _visible) await widget.onDisplayed!(rows);
      }
    } catch (e) {
      if (mounted) setState(() => _error = widget.errorLabel(e));
    } finally {
      if (mounted && !quiet) setState(() => _busy = false);
      _loading = null;
      completion.complete();
      if (mounted && updated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final current = _scroll.position;
          // Al anteponer historial, conserva la zona que se estaba leyendo.
          final target = stick
              ? current.maxScrollExtent
              : more
              ? pixels + current.maxScrollExtent - extent
              : pixels;
          if (stick) {
            _scrollLatest();
          } else {
            _scroll.jumpTo(target.clamp(0.0, current.maxScrollExtent));
          }
        });
      }
    }
  }

  void _scrollLatest([int remaining = 3]) {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
    if (remaining == 0) return;
    // ListView estima las filas fuera de pantalla. Reajusta de forma acotada
    // tras medirlas para alcanzar el último mensaje, también con texto largo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _scroll.position.extentAfter > 1) {
        _scrollLatest(remaining - 1);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
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

  Widget _composer() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _body,
        enabled: !_sending && _pending == null,
        readOnly: _header?.canSend != true,
        maxLength: 4000,
        minLines: 1,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.messageLabel,
          helperText: _header?.canSend != true && _pending == null
              ? 'Puedes copiar tu borrador.'
              : null,
          helperMaxLines: 2,
        ),
      ),
      if (_sendError != null) Text(_sendError!),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed:
              (_header?.canSend != true && _pending == null) ||
                  _busy ||
                  _sending ||
                  (_pending ?? _body.text.trim()).isEmpty
              ? null
              : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(
            _pending == null ? 'Enviar mensaje' : 'Reintentar el mismo envío',
          ),
        ),
      ),
    ],
  );

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
    body: Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ProfessionalWorkspaceScope.isDesktop(context)
                    ? 1200
                    : 900,
              ),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_header?.notice case final notice?) Text(notice),
                  if (_header?.actions case final actions?)
                    Wrap(spacing: 8, runSpacing: 8, children: actions(_load)),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar consulta'),
                    ),
                  ],
                  Text(
                    widget.refreshInterval == null
                        ? 'Actualiza para consultar respuestas.'
                        : 'Las respuestas se actualizan automáticamente.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_more)
                    TextButton(
                      onPressed: _busy || _sending
                          ? null
                          : () => _load(more: true),
                      child: const Text('Cargar mensajes anteriores'),
                    ),
                  if (!_busy && _items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Todavía no hay mensajes.'),
                    ),
                  for (final entry in _items.reversed)
                    Align(
                      alignment: entry.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              ProfessionalWorkspaceScope.isDesktop(context)
                              ? 720
                              : double.infinity,
                        ),
                        child: Card(
                          color:
                              ProfessionalWorkspaceScope.isDesktop(context) &&
                                  entry.mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
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
                                  entry.createdAt
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_newMessages)
          TextButton.icon(
            onPressed: () {
              setState(() => _newMessages = false);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollLatest(),
              );
            },
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Ver mensajes nuevos'),
          ),
        if (_header?.canSend == false)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _header?.readOnlyMessage ?? 'Conversación conservada en consulta. El servicio no admite nuevos envíos ahora.',
              ),
            ),
          ),
        if (_header?.canSend == true ||
            _pending != null ||
            _body.text.trim().isNotEmpty)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _composer(),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
