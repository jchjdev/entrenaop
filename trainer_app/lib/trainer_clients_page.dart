import 'client_relation_history.dart';
import 'trainer_client_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/trainer_access.dart';

class TrainerClientsPage extends StatefulWidget {
  const TrainerClientsPage({
    super.key,
    required this.repository,
    this.onSignOut,
    this.onOpenWorkouts,
    this.onOpenClient,
    this.onOpenTechnique,
    this.techniqueMode = false,
  });
  final TrainerRepository repository;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onOpenWorkouts;
  final ValueChanged<String>? onOpenClient;
  final ValueChanged<String>? onOpenTechnique;
  final bool techniqueMode;
  @override
  State<TrainerClientsPage> createState() => _TrainerClientsPageState();
}

class _TrainerClientsPageState extends State<TrainerClientsPage> {
  TrainerAccess? _access;
  List<TrainerClient> _clients = [];
  TrainerClientState _clientState = TrainerClientState.active;
  List<TrainerInvitation> _invitations = [];
  TrainerInvitationDraft? _draft;
  bool _busy = true, _moreClients = false, _moreInvitations = false;
  bool _created = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _load() async {
    final access = await widget.repository.access();
    final clients = await widget.repository.clients(state: _clientState);
    final invitations = widget.techniqueMode
        ? <TrainerInvitation>[]
        : await widget.repository.invitations();
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

  Future<void> _manage(TrainerClient client, TrainerClientAction action) async {
    if (_busy) return;
    if (action == TrainerClientAction.history) {
      await showDialog<void>(
        context: context,
        builder: (_) => ClientRelationHistory(
          repository: widget.repository,
          client: client,
        ),
      );
      return;
    }
    final deactivate = action == TrainerClientAction.deactivate;
    final archive = action == TrainerClientAction.archive;
    final confirmed = await _confirm(
      deactivate
          ? 'Desactivar servicio'
          : archive
          ? 'Archivar cliente'
          : 'Recuperar cliente',
      deactivate
          ? 'Se liberará la plaza de ${client.name}. Su ficha y las etapas del servicio se conservan. Para volver necesitará aceptar una nueva invitación.'
          : archive
          ? 'La ficha pasará a Archivados. No se borran etapas ni resultados del alumno.'
          : 'La ficha volverá a Inactivos. Esto no reactiva el servicio ni ocupa plaza.',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      if (deactivate) {
        await widget.repository.endRelation(client.activeRelationId!);
      } else {
        await widget.repository.archiveClient(
          client.personId,
          archived: archive,
        );
      }
      await _load();
    });
  }

  Widget _clientCards() {
    final openClient = widget.techniqueMode
        ? widget.onOpenTechnique
        : widget.onOpenClient;
    return ProfessionalCatalogGrid(
      minCardWidth: 300,
      children: [
        for (final client in _clients)
          TrainerClientCard(
            key: ValueKey(client.personId),
            client: client,
            busy: _busy,
            techniqueMode: widget.techniqueMode,
            onOpen: openClient == null
                ? null
                : () => openClient(client.personId),
            onTechnique: widget.onOpenTechnique == null
                ? null
                : () => widget.onOpenTechnique!(client.personId),
            onManage: (action) => _manage(client, action),
          ),
      ],
    );
  }

  Widget _invitation(TrainerInvitation invite) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            invite.status == 'Pendiente'
                ? 'Invitación pendiente'
                : invite.status,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text('Creada el ${trainerDate(invite.createdAt)}'),
          Text(
            invite.acceptedAt != null
                ? 'Aceptada el ${trainerDate(invite.acceptedAt!)}'
                : invite.revokedAt != null
                ? 'Cancelada el ${trainerDate(invite.revokedAt!)}'
                : '${invite.status == 'Caducada' ? 'Caducó' : 'Caduca'} el ${trainerDate(invite.expiresAt)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Referencia ${invite.id.substring(0, 8)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (invite.status == 'Pendiente' && invite.canCancel)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await _confirm(
                              'Cancelar invitación',
                              'Este código dejará de admitir alumnos. Los vínculos ya aceptados se mantienen.',
                            ) ||
                            !mounted) {
                          return;
                        }
                        await _run(() async {
                          await widget.repository.cancelInvitation(invite.id);
                          if (_draft?.id == invite.id) {
                            _draft = null;
                          }
                          await _load();
                        });
                      },
                child: const Text('Cancelar invitación'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _invitationsSection() {
    final pending = _invitations.where((i) => i.status == 'Pendiente').toList();
    final history = _invitations.where((i) => i.status != 'Pendiente').toList();
    return _section(
      'Invitaciones',
      'Pendientes de aceptar. No reservan plaza.',
      [
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _moreInvitations
                  ? 'No hay pendientes en las invitaciones mostradas.'
                  : 'No tienes invitaciones pendientes.',
            ),
          ),
        for (final invitation in pending) _invitation(invitation),
        if (history.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Historial de invitaciones'),
            subtitle: const Text('Aceptadas, canceladas y caducadas'),
            children: [
              for (final invitation in history) _invitation(invitation),
            ],
          ),
        if (_moreInvitations)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final more = await widget.repository.invitations(
                      before: _invitations.last,
                    );
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
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ProfessionalWorkspaceScope.isDesktop(context)
        ? null
        : AppBar(
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
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1160,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!ProfessionalWorkspaceScope.isDesktop(context))
              const Text('ESPACIO PROFESIONAL'),
            if (!ProfessionalWorkspaceScope.isDesktop(context) &&
                !widget.techniqueMode &&
                widget.onOpenWorkouts != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : widget.onOpenWorkouts,
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Mis sesiones privadas'),
                ),
              ),
            if (ProfessionalWorkspaceScope.isDesktop(context))
              ProfessionalSectionHeader(
                title: widget.techniqueMode
                    ? 'Vídeos de tus alumnos'
                    : 'Tus alumnos',
                subtitle: widget.techniqueMode
                    ? 'Elige un alumno y abre los vídeos compartidos de sus sesiones.'
                    : 'Abre la ficha de un alumno para planificar y revisar su evolución.',
                actions: [
                  IconButton(
                    onPressed: _busy ? null : _refresh,
                    tooltip: 'Actualizar',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                widget.techniqueMode ? 'Vídeos de tus alumnos' : 'Tus alumnos',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.techniqueMode
                    ? 'Elige un alumno y abre los vídeos compartidos de sus sesiones.'
                    : 'Abre la ficha de un alumno para planificar y revisar su evolución.',
              ),
            ],
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
              if (!widget.techniqueMode)
                EntrenaCard(
                  tone:
                      ProfessionalWorkspaceScope.isDesktop(context) &&
                          access.effective
                      ? EntrenaCardTone.quiet
                      : EntrenaCardTone.accent,
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
              if (!widget.techniqueMode && _draft != null) ...[
                _section(
                  _created ? 'Invitación preparada' : 'Confirmar invitación',
                  _created
                      ? 'Copia el código y envíaselo al alumno por tu canal habitual. En su app: Perfil → Mi preparador → Ver invitación.'
                      : 'Si la conexión falla, reintenta esta misma invitación para evitar duplicados.',
                  [
                    if (_created) ...[
                      SelectableText(
                        _draft!.secret,
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
                                  ClipboardData(text: _draft!.secret),
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
                    'Tu cartera conserva las etapas activas e inactivas del servicio.',
                    [
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
                              selected: _clientState == state,
                              onSelected: _busy
                                  ? null
                                  : (_) {
                                      _clientState = state;
                                      _refresh();
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_clients.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(switch (_clientState) {
                            TrainerClientState.active =>
                              'Tu primer alumno empieza con una invitación.',
                            TrainerClientState.inactive =>
                              'Todavía no hay clientes inactivos.',
                            TrainerClientState.archived =>
                              'No tienes clientes archivados.',
                          }),
                        ),
                      _clientCards(),
                      const SizedBox(height: 16),
                      if (_moreClients)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  final more = await widget.repository.clients(
                                    state: _clientState,
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
                  if (widget.techniqueMode) return clients;
                  final invitations = _invitationsSection();
                  if (constraints.maxWidth < 1000 ||
                      MediaQuery.textScalerOf(context).scale(14) >= 21) {
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
                      Expanded(child: invitations),
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
