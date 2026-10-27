import 'dart:async';

import 'package:trainer_access/trainer_messages.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/professional_tools_workspace.dart';

/// Los formularios mantienen toda la pantalla y su guard de salida propio.
class TrainerShell extends StatefulWidget {
  const TrainerShell({
    super.key,
    required this.location,
    required this.child,
    this.loadInbox,
    this.messageChanges,
  });
  final Future<TrainerMessageInbox> Function()? loadInbox;
  final Listenable? messageChanges;
  final String location;
  final Widget child;
  static const destinations = [
    ('/home', 'Inicio', Icons.home_outlined),
    ('/clients', 'Alumnos', Icons.people_outline),
    ('/self', 'Para mí', Icons.person_outline),
    ('/agenda', 'Agenda', Icons.calendar_month_outlined),
    ('/workouts', 'Sesiones', Icons.fitness_center),
    ('/programs', 'Programas', Icons.view_week_outlined),
    ('/exercises', 'Ejercicios', Icons.sports_gymnastics),
    ('/reviews', 'Revisiones', Icons.fact_check_outlined),
    ('/forms', 'Formularios', Icons.assignment_outlined),
    ('/assessments', 'Pruebas y simulacros', Icons.timer_outlined),
    ('/groups', 'Grupos', Icons.groups_outlined),
    ('/media', 'Vídeos', Icons.video_library_outlined),
    ('/recurrence', 'Programar semanas', Icons.event_repeat_outlined),
    ('/messages', 'Conversaciones', Icons.chat_bubble_outline),
    ('/reports', 'Informes', Icons.insights),
    ('/settings', 'Mi cuenta', Icons.settings_outlined),
  ];
  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell>
    with WidgetsBindingObserver {
  TrainerMessageInbox? _inbox;
  bool _checking = false, _checkFailed = false;
  Timer? _timer;
  int get _unread => _inbox?.totalUnread ?? 0;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.messageChanges?.addListener(_refreshInbox);
    if (widget.loadInbox != null) {
      _refreshInbox();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_foreground) _refreshInbox();
      });
    }
  }

  @override
  void didUpdateWidget(TrainerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageChanges != widget.messageChanges) {
      oldWidget.messageChanges?.removeListener(_refreshInbox);
      widget.messageChanges?.addListener(_refreshInbox);
    }
    if (oldWidget.location != widget.location && _foreground) _refreshInbox();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshInbox();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.messageChanges?.removeListener(_refreshInbox);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshInbox() async {
    if (_checking || widget.loadInbox == null || !_foreground) return;
    _checking = true;
    try {
      final inbox = await widget.loadInbox!();
      if (mounted) {
        setState(() {
          _inbox = inbox;
          _checkFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkFailed = true);
    } finally {
      _checking = false;
    }
  }

  Widget _messageIcon(IconData icon) => Badge.count(
    count: _unread,
    isLabelVisible: _unread > 0,
    child: Icon(icon),
  );
  Future<void> _openInbox() async {
    final relationId = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Mensajes sin leer')),
              if (_checkFailed)
                const ListTile(
                  title: Text(
                    'No se pudo actualizar el contador. Vuelve a comprobarlo.',
                  ),
                ),
              for (final item
                  in _inbox?.conversations ?? <TrainerUnreadConversation>[])
                ListTile(
                  leading: Badge.count(
                    count: item.unreadCount,
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  title: Text(item.clientName),
                  subtitle: Text('${item.unreadCount} mensajes sin leer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, item.relationId),
                ),
              if ((_inbox?.conversations.length ?? 0) == 50)
                const ListTile(
                  title: Text(
                    'Se muestran las 50 conversaciones más recientes. El contador incluye todas.',
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, ''),
                child: const Text('Ver todas las conversaciones'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || relationId == null) return;
    context.go(relationId.isEmpty ? '/messages' : '/conversations/$relationId');
  }

  Widget _noticeButton() => IconButton(
    key: const ValueKey('trainer-message-notices'),
    tooltip: _checkFailed
        ? 'No se pudieron comprobar los mensajes. Reintentar'
        : '$_unread mensajes sin leer',
    onPressed: _checkFailed ? _refreshInbox : _openInbox,
    icon: _messageIcon(
      _checkFailed ? Icons.sync_problem_outlined : Icons.notifications_outlined,
    ),
  );

  final _scaffold = GlobalKey<ScaffoldState>();
  String get location => widget.location;
  Widget get child => widget.child;
  static const destinations = TrainerShell.destinations;
  // Conserva los cuatro accesos habituales en pantallas estrechas. «Para mí»
  // está en Más y no desplaza Sesiones al añadir una opción al escritorio.
  static const compactDestinations = [0, 1, 3, 4];

  @override
  Widget build(BuildContext context) =>
      ProfessionalToolsWorkspace(child: Builder(builder: _buildShell));

  Widget _buildShell(BuildContext context) {
    final index = destinations.indexWhere((d) => location.startsWith(d.$1));
    final selected = index >= 0
        ? index
        : destinations.indexWhere(
            (d) =>
                d.$1 ==
                (location.startsWith('/conversations/')
                    ? '/messages'
                    : '/agenda'),
          );
    void go(int value) {
      if (location != destinations[value].$1) {
        context.go(destinations[value].$1);
      }
    }

    Future<void> more() async {
      final destination = await showModalBottomSheet<int>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Calculadora de ritmos'),
                subtitle: const Text('Herramientas'),
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
              for (final i in [
                2,
                for (var value = 5; value < destinations.length; value++) value,
              ])
                ListTile(
                  leading: i == 13
                      ? _messageIcon(destinations[i].$3)
                      : Icon(destinations[i].$3),
                  title: Text(destinations[i].$2),
                  selected: selected == i,
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      );
      if (destination != null && context.mounted) {
        if (destination == -1) {
          ProfessionalToolsWorkspace.openCalculator(context);
        } else {
          go(destination);
        }
      }
    }

    return ProfessionalWorkspaceShell(
      scaffoldKey: _scaffold,
      navigation: Material(
        color: context.visuals.surfaceLow,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntrenaWordmark(width: 132),
                    SizedBox(height: 8),
                    Text(
                      'PREPARADORES',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (const {
                        0: 'TU ESPACIO',
                        4: 'BIBLIOTECA',
                        7: 'SEGUIMIENTO',
                        10: 'ORGANIZACIÓN',
                        13: 'SERVICIO',
                      }.containsKey(i))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
                          child: Text(
                            const {
                              0: 'TU ESPACIO',
                              4: 'BIBLIOTECA',
                              7: 'SEGUIMIENTO',
                              10: 'ORGANIZACIÓN',
                              13: 'SERVICIO',
                            }[i]!,
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: .9,
                              color: Color(0xFFAAB5C4),
                            ),
                          ),
                        ),
                      ListTile(
                        dense: true,
                        minTileHeight: 36,
                        minVerticalPadding: 4,
                        key: ValueKey('trainer-nav-${destinations[i].$1}'),
                        selected: selected == i,
                        selectedTileColor: context.visuals.accentSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        minLeadingWidth: 22,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        leading: i == 13
                            ? _messageIcon(destinations[i].$3)
                            : Icon(destinations[i].$3, size: 18),
                        title: Text(destinations[i].$2),
                        onTap: () => go(i),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: ProfessionalToolsButton(),
              ),
            ],
          ),
        ),
      ),
      headerBuilder: (context, desktop) => desktop
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                'Preparadores / ${destinations[selected].$2}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              actions: [
                if (_unread > 0 || _checkFailed) _noticeButton(),
                const ProfessionalToolsButton(iconOnly: true),
                const SizedBox(width: 12),
              ],
            )
          : const SizedBox.shrink(),
      compactNavigation: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_unread > 0 || _checkFailed) _noticeButton(),
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: TextButton(
                    onPressed: i == 4 ? more : () => go(compactDestinations[i]),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      backgroundColor:
                          (i == 4
                              ? !compactDestinations.contains(selected)
                              : compactDestinations[i] == selected)
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == 4
                              ? Icons.more_horiz
                              : destinations[compactDestinations[i]].$3,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            i == 4
                                ? 'Más'
                                : destinations[compactDestinations[i]].$2,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}
