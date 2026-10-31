import 'dart:async';

import 'package:entrena_ui/conversation_view.dart';
import 'package:flutter/material.dart';

import '../directory/domain.dart';
import '../trainer_messages.dart';
import 'domain.dart';
import 'policy.dart';

String contactStateLabel(ContactConversation c) => c.relationId != null
    ? 'Vínculo de preparación creado'
    : switch (c.state) {
        ContactState.fresh => 'Primer contacto',
        ContactState.pending =>
          c.isTrainer
              ? 'Solicitud pendiente'
              : 'Esperando respuesta del preparador',
        ContactState.accepted => 'Conversación aceptada',
        ContactState.declined => 'Contacto rechazado',
        ContactState.blocked => 'Contacto bloqueado',
      };

String contactReadOnlyMessage(ContactConversation c) => switch (c.state) {
  ContactState.pending =>
    c.isTrainer ? 'Acepta el contacto para poder responder.' : 'Tu primer mensaje está enviado. No puedes enviar más hasta que el preparador acepte el contacto.',
  ContactState.declined =>
    c.isTrainer
        ? 'Has rechazado esta solicitud. No se pueden enviar más mensajes.'
        : 'El preparador ha rechazado la solicitud. No puedes enviar más mensajes a este contacto.',
  ContactState.blocked =>
    'Este contacto está bloqueado. No se pueden enviar más mensajes.',
  _ => 'Esta conversación no admite nuevos mensajes ahora. Puedes consultar el historial.',
};

String contactConversationNotice(ContactConversation c) {
  if (c.relationId != null) {
    return 'El vínculo de preparación ya está creado. Abre su chat para continuar.';
  }
  return switch (c.state) {
    ContactState.fresh => contactNotice,
    ContactState.pending ||
    ContactState.declined ||
    ContactState.blocked => contactStateLabel(c),
    ContactState.accepted =>
      c.isTrainer
          ? 'Contacto aceptado. Podéis conversar. Para empezar el seguimiento, prepara una invitación de alumno; la otra persona deberá aceptarla.'
          : 'El preparador ha aceptado el contacto. Ya puedes escribirle. Para empezar el seguimiento necesitarás aceptar su invitación de alumno.',
  };
}

class ContactInboxPage extends StatefulWidget {
  const ContactInboxPage({
    super.key,
    required this.repository,
    required this.onOpen,
    this.hideLinked = false,
  });
  final ContactRepository repository;
  final FutureOr<void> Function(ContactConversation) onOpen;
  final bool hideLinked;
  @override
  State<ContactInboxPage> createState() => _ContactInboxPageState();
}

class _ContactInboxPageState extends State<ContactInboxPage> {
  final _items = <ContactConversation>[];
  bool _busy = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.repository.inbox(
        before: more && _items.isNotEmpty ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          if (!more) _items.clear();
          _items.addAll(page.items);
          _more = page.items.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((c) => !widget.hideLinked || c.relationId == null)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos y solicitudes'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (!_busy && visible.isEmpty && _error == null)
              Text(
                widget.hideLinked
                    ? 'No hay contactos sin vincular en esta página. Los chats de alumnos están en Alumnos.'
                    : 'Todavía no tienes contactos del directorio.',
              ),
            for (final c in visible)
              Card(
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text(contactStateLabel(c)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpen(c);
                    if (mounted) await _load();
                  },
                ),
              ),
            if (_more)
              TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Ver más contactos'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compone el chat existente con el contexto y las acciones del primer contacto.
class ContactConversationPage extends StatefulWidget {
  const ContactConversationPage({
    super.key,
    required this.repository,
    required this.onService,
    this.profileId,
    this.contactId,
    this.onRead,
    this.onInviteStudent,
    this.onStateChanged,
  }) : assert((profileId == null) != (contactId == null));
  final ContactRepository repository;
  final String? profileId, contactId;
  final ValueChanged<String> onService;
  final VoidCallback? onRead;
  final VoidCallback? onInviteStudent;
  final VoidCallback? onStateChanged;
  @override
  State<ContactConversationPage> createState() =>
      _ContactConversationPageState();
}

class _ContactConversationPageState extends State<ContactConversationPage> {
  ContactConversation? _context;
  String? _id;
  bool _acting = false, _redirected = false;
  final _read = <String>{};
  @override
  void initState() {
    super.initState();
    _id = widget.contactId;
  }

  void _service(String relationId) {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onService(relationId);
    });
  }

  Future<ConversationHeader> _header() async {
    final c = _id == null
        ? await widget.repository.open(widget.profileId!)
        : await widget.repository.context(_id!);
    _context = c;
    _id = c.id;
    if (c.relationId case final id?) _service(id);
    return ConversationHeader(
      title: c.name,
      canSend: c.canSend && c.relationId == null,
      notice: contactConversationNotice(c),
      readOnlyMessage: contactReadOnlyMessage(c),
      actions: (refresh) => [
        if (c.isTrainer &&
            c.state == ContactState.accepted &&
            c.relationId == null &&
            widget.onInviteStudent != null)
          FilledButton.icon(
            onPressed: widget.onInviteStudent,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Invitar como alumno'),
          ),
        if (c.relationId case final relation?)
          FilledButton(
            onPressed: () => widget.onService(relation),
            child: const Text('Abrir chat de preparación'),
          ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Privacidad del contacto'),
              scrollable: true,
              content: const SizedBox(
                width: 600,
                child: SelectableText(contactPrivacyInformation),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
          child: const Text('Privacidad del contacto'),
        ),
        if (c.canDecide) ...[
          FilledButton(
            onPressed: _acting
                ? null
                : () => _decide(ContactState.accepted, refresh),
            child: const Text('Aceptar contacto'),
          ),
          OutlinedButton(
            onPressed: _acting
                ? null
                : () => _decide(ContactState.declined, refresh),
            child: const Text('Rechazar contacto'),
          ),
        ],
        if (c.id != null &&
            c.relationId == null &&
            c.state != ContactState.blocked)
          TextButton(
            onPressed: _acting
                ? null
                : () => _decide(ContactState.blocked, refresh),
            child: const Text('Bloquear contacto'),
          ),
        if (c.id != null && !c.isTrainer)
          TextButton(
            onPressed: _acting ? null : _report,
            child: const Text('Denunciar preparador'),
          ),
      ],
    );
  }

  Future<void> _decide(
    ContactState state,
    Future<void> Function() refresh,
  ) async {
    if (_acting || _id == null) return;
    if (state == ContactState.blocked &&
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Bloquear este contacto?'),
                content: const Text(
                  'Este contacto dejará de admitir mensajes. Se conserva la conversación en consulta.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Bloquear'),
                  ),
                ],
              ),
            ) !=
            true) {
      return;
    }
    if (!mounted) return;
    setState(() => _acting = true);
    try {
      await widget.repository.decide(_id!, state);
      widget.onStateChanged?.call();
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(directoryError(e))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _report() async {
    final details = TextEditingController();
    DirectoryReportReason reason = DirectoryReportReason.other;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Denunciar al preparador'),
          scrollable: true,
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'La denuncia se revisará en ADMIN. Puedes bloquear el contacto para detener nuevos mensajes.',
                ),
                DropdownButtonFormField<DirectoryReportReason>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: reason,
                  items: DirectoryReportReason.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(switch (r) {
                            DirectoryReportReason.explicit =>
                              'Contenido explícito',
                            DirectoryReportReason.harassment => 'Acoso u odio',
                            DirectoryReportReason.impersonation =>
                              'Suplantación',
                            DirectoryReportReason.spam => 'Spam o engaño',
                            DirectoryReportReason.misleading =>
                              'Información profesional falsa',
                            DirectoryReportReason.other => 'Otro motivo',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (r) => update(() => reason = r!),
                ),
                TextField(
                  controller: details,
                  maxLength: 850,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Explica el motivo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar denuncia'),
            ),
          ],
        ),
      ),
    );
    final body = details.text;
    details.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.report(_id!, reason, body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denuncia recibida para revisión.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(directoryError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ConversationView(
    header: _header,
    refreshInterval: const Duration(seconds: 15),
    messageLabel: 'Mensaje para el preparador',
    load: (before) async => _id == null
        ? []
        : (await widget.repository.messages(
                _id!,
                beforeAt: before?.createdAt,
                beforeId: before?.id,
              ))
              .map(
                (m) => ConversationEntry(
                  id: m.id,
                  body: m.body,
                  createdAt: m.createdAt,
                  mine: m.mine,
                ),
              )
              .toList(),
    send: (operation, body) async {
      if (_id == null) {
        final c = await widget.repository.request(
          operationId: operation,
          profileId: widget.profileId!,
          body: body,
        );
        _id = c.id;
        if (c.relationId case final id?) _service(id);
      } else {
        await widget.repository.send(
          operationId: operation,
          contactId: _id!,
          body: body,
        );
      }
    },
    onDisplayed: (rows) async {
      if (_context?.isTrainer != true || _id == null) return;
      final ids = rows
          .where((m) => !m.mine && !_read.contains(m.id))
          .map((m) => m.id)
          .toList();
      await widget.repository.markRead(_id!, ids);
      _read.addAll(ids);
      if (ids.isNotEmpty) widget.onRead?.call();
    },
    newOperationId: trainerMessageOperationId,
    errorLabel: directoryError,
  );
}
