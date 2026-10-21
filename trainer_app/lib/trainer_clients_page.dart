import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/trainer_access.dart';

class TrainerClientsPage extends StatefulWidget {
  const TrainerClientsPage({
    super.key,
    required this.repository,
    this.onSignOut,
  });
  final TrainerRepository repository;
  final Future<void> Function()? onSignOut;
  @override
  State<TrainerClientsPage> createState() => _TrainerClientsPageState();
}

class _TrainerClientsPageState extends State<TrainerClientsPage> {
  TrainerAccess? _access;
  List<TrainerRelation> _clients = [];
  List<TrainerInvitation> _invitations = [];
  TrainerInvitationDraft? _draft;
  bool _busy = true,
      _ended = false,
      _moreClients = false,
      _moreInvitations = false;
  bool _created = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _load() async {
    final access = await widget.repository.access();
    final clients = await widget.repository.relations(
      asTrainer: true,
      ended: _ended,
    );
    final invitations = await widget.repository.invitations();
    if (!mounted) return;
    setState(() {
      _access = access;
      _clients = clients;
      _invitations = invitations;
      _moreClients = clients.length == 50;
      _moreInvitations = invitations.length == 50;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _access = null;
    });
    try {
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text),
              const SizedBox(height: 20),
              EntrenaDialogActions(
                primaryLabel: 'Volver',
                onPrimary: () => Navigator.pop(context, false),
                secondary: [
                  OutlinedButton(
                    style: EntrenaButtonStyles.destructive(context),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(title),
                  ),
                ],
              ),
            ],
          ),
          actions: const [],
        ),
      ) ==
      true;

  Widget _section(String title, String subtitle, List<Widget> children) =>
      EntrenaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const EntrenaWordmark(),
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
        if (widget.onSignOut != null)
          IconButton(
            onPressed: () => _run(widget.onSignOut!),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('ESPACIO PROFESIONAL'),
            const SizedBox(height: 8),
            Text(
              'Tus alumnos',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text('Invita, consulta y gestiona tus vínculos.'),
            const SizedBox(height: 24),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_notice != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_notice!)),
            if (_access case final access?) ...[
              EntrenaCard(
                tone: EntrenaCardTone.accent,
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          access.status,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${access.activeClients} de ${access.limit} plazas ocupadas',
                        ),
                        if (access.validUntil != null)
                          Text(
                            'Vigente hasta el ${trainerDate(access.validUntil!)}',
                          ),
                      ],
                    ),
                    if (!access.effective)
                      const SizedBox(
                        width: 360,
                        child: Text(
                          'Consulta con EntrenaOP tu acceso profesional. Puedes consultar y finalizar tus vínculos anteriores.',
                        ),
                      ),
                    if (access.effective && access.full)
                      const SizedBox(
                        width: 360,
                        child: Text(
                          'Todas tus plazas están ocupadas. Las invitaciones no reservan plaza; se comprueba al aceptarlas.',
                        ),
                      ),
                    FilledButton.icon(
                      onPressed:
                          _busy ||
                              !access.effective ||
                              access.full ||
                              _draft != null
                          ? null
                          : () {
                              setState(() {
                                _draft = TrainerInvitationDraft.secure();
                                _created = false;
                              });
                              _create();
                            },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Invitar alumno'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_draft case final draft?) ...[
                _section(
                  _created ? 'Invitación preparada' : 'Confirmar invitación',
                  _created
                      ? 'Copia el código y envíaselo al alumno por tu canal habitual. En su app: Perfil → Mi preparador → Ver invitación.'
                      : 'Si la conexión falla, reintenta esta misma invitación para evitar duplicados.',
                  [
                    if (_created) ...[
                      SelectableText(
                        draft.secret,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El código solo se muestra en esta pantalla. Caduca a los siete días y sirve para una única aceptación.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await Clipboard.setData(
                                  ClipboardData(text: draft.secret),
                                );
                                if (mounted) {
                                  setState(() => _notice = 'Código copiado.');
                                }
                              }),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _draft = null),
                        child: const Text('Ya he guardado el código'),
                      ),
                    ] else
                      FilledButton(
                        onPressed: _busy ? null : _create,
                        child: const Text('Reintentar invitación'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final clients = _section(
                    'Alumnos',
                    'Solo aparecen tus vínculos aceptados.',
                    [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Activos'),
                            selected: !_ended,
                            onSelected: _busy
                                ? null
                                : (_) {
                                    _ended = false;
                                    _refresh();
                                  },
                          ),
                          ChoiceChip(
                            label: const Text('Finalizados'),
                            selected: _ended,
                            onSelected: _busy
                                ? null
                                : (_) {
                                    _ended = true;
                                    _refresh();
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_clients.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _ended ? 'Todavía no hay vínculos finalizados.' : 'Tu primer alumno empieza con una invitación.',
                          ),
                        ),
                      for (final relation in _clients)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                relation.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                relation.endedAt == null
                                    ? 'Vinculado desde el ${trainerDate(relation.acceptedAt)}'
                                    : 'Finalizado el ${trainerDate(relation.endedAt!)}',
                              ),
                              if (relation.endedAt == null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            if (!await _confirm(
                                              'Finalizar vínculo',
                                              'Se liberará la plaza de ${relation.name}. Para volver necesitará aceptar una nueva invitación. Su historial personal se conserva.',
                                            )) {
                                              return;
                                            }
                                            if (!mounted) return;
                                            await _run(() async {
                                              await widget.repository
                                                  .endRelation(relation.id);
                                              await _load();
                                            });
                                          },
                                    child: const Text('Finalizar vínculo'),
                                  ),
                                ),
                              const Divider(),
                            ],
                          ),
                        ),
                      if (_moreClients)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  final more = await widget.repository
                                      .relations(
                                        asTrainer: true,
                                        ended: _ended,
                                        before: _clients.last,
                                      );
                                  if (mounted) {
                                    setState(() {
                                      _clients.addAll(more);
                                      _moreClients = more.length == 50;
                                    });
                                  }
                                }),
                          child: const Text('Más alumnos'),
                        ),
                    ],
                  );
                  final invitations = _section(
                    'Invitaciones',
                    'Las pendientes no ocupan plaza.',
                    [
                      if (_invitations.isEmpty)
                        const Text('Aún no has creado invitaciones.'),
                      for (final invite in _invitations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Invitación ${invite.id.substring(0, 8)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${invite.status} · Creada el ${trainerDate(invite.createdAt)}',
                              ),
                              Text(
                                'Caduca el ${trainerDate(invite.expiresAt)}',
                              ),
                              if (invite.canCancel)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            if (!await _confirm(
                                              'Cancelar invitación',
                                              'Este código dejará de admitir alumnos. Los vínculos ya aceptados se mantienen.',
                                            )) {
                                              return;
                                            }
                                            if (!mounted) return;
                                            await _run(() async {
                                              await widget.repository
                                                  .cancelInvitation(invite.id);
                                              if (_draft?.id == invite.id) {
                                                _draft = null;
                                              }
                                              await _load();
                                            });
                                          },
                                    child: const Text('Cancelar invitación'),
                                  ),
                                ),
                              const Divider(),
                            ],
                          ),
                        ),
                      if (_moreInvitations)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  final more = await widget.repository
                                      .invitations(before: _invitations.last);
                                  if (mounted) {
                                    setState(() {
                                      _invitations.addAll(more);
                                      _moreInvitations = more.length == 50;
                                    });
                                  }
                                }),
                          child: const Text('Más invitaciones'),
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 800) {
                    return Column(
                      children: [
                        clients,
                        const SizedBox(height: 20),
                        invitations,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: clients),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: invitations),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _create() => _run(() async {
    final draft = _draft!;
    await widget.repository.createInvitation(draft);
    if (!mounted) return;
    setState(() => _created = true);
    await _load();
  });
}
