import 'dart:async';

import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/features/notifications/push_notifications_scope.dart';
import 'package:entrenaop/core/navigation/app_account_actions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/student_notice_repository.dart';
import '../widgets/professional_resources.dart';
import '../student_navigation.dart';

String? studentNoticeTargetRoute(StudentNoticeTarget target) {
  final id = Uri.encodeComponent(target.targetId);
  return switch (target.kind) {
    StudentNoticeTargetKind.conversation => '/my-trainer/conversations/$id',
    StudentNoticeTargetKind.appointment => '/my-trainer/appointments/$id',
    StudentNoticeTargetKind.form => '/my-trainer/forms/$id',
    StudentNoticeTargetKind.assessment => '/my-trainer/assessments/$id',
    StudentNoticeTargetKind.technique => '/my-trainer/technique/$id',
    StudentNoticeTargetKind.workout =>
      target.scheduledDate == null
          ? null
          : '/plan/week?date=${_day(target.scheduledDate!)}&session=$id',
    StudentNoticeTargetKind.planning =>
      target.scheduledDate == null
          ? null
          : '/plan/week?date=${_day(target.scheduledDate!)}',
  };
}

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ProfessionalHubPage extends StatefulWidget {
  const ProfessionalHubPage({
    super.key,
    required this.repository,
    required this.userId,
    this.onOpen,
    this.focusNotices = false,
    this.noticeEvents,
  });
  final StudentNoticeRepository repository;
  final String userId;
  final Future<void> Function(String)? onOpen;
  final bool focusNotices;
  final Stream<void>? noticeEvents;

  @override
  State<ProfessionalHubPage> createState() => _ProfessionalHubPageState();
}

class _ProfessionalHubPageState extends State<ProfessionalHubPage>
    with WidgetsBindingObserver {
  StudentNoticeSnapshot? _data;
  List<StudentNotice> _items = [];
  StudentNoticeKind? _kind;
  bool _busy = true;
  String? _error, _action;
  int _request = 0;
  StreamSubscription<void>? _push;
  late bool _showNotices = widget.focusNotices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _listenPush();
  }

  void _listenPush() {
    unawaited(_push?.cancel());
    _push = widget.noticeEvents?.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant ProfessionalHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noticeEvents != widget.noticeEvents) _listenPush();
    if (oldWidget.focusNotices != widget.focusNotices) {
      _showNotices = widget.focusNotices;
    }
    if (oldWidget.userId != widget.userId ||
        oldWidget.repository != widget.repository) {
      _data = null;
      _items = [];
      _kind = null;
      _action = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (GoRouter.maybeOf(context)?.state.uri.path ?? '/my-trainer') ==
            '/my-trainer') {
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_busy || _items.isEmpty)) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.repository.snapshot(
        before: more ? _items.last : null,
        kind: _kind,
      );
      if (!mounted || request != _request) return;
      StudentNavigationScope.maybeOf(context)?.acceptSnapshot(data);
      setState(() {
        _data = data;
        _items = more
            ? {
                for (final item in [..._items, ...data.items]) item.id: item,
              }.values.toList()
            : data.items;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'No se pudo actualizar tu seguimiento. Puedes reintentar.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _openRoute(String route) async {
    final owner = widget.userId;
    if (widget.onOpen case final open?) {
      await open(route);
    } else {
      await context.push(route);
    }
    if (mounted && owner == widget.userId) await _load();
  }

  void _selectView(bool notices) {
    setState(() => _showNotices = notices);
    // La campana puede volver a abrir Avisos después de visitar Resumen.
    if (GoRouter.maybeOf(context)?.state.uri.path == '/my-trainer') {
      context.go(notices ? '/my-trainer?view=notices' : '/my-trainer');
    }
  }

  Future<void> _noticeAction(
    StudentNotice notice, {
    required bool acknowledge,
  }) async {
    if (_action != null) return;
    final owner = widget.userId;
    final repository = widget.repository;
    setState(() {
      _action = notice.id;
      _error = null;
    });
    try {
      if (acknowledge) {
        await repository.ack(notice.id, generation: notice.groupGeneration);
        if (!mounted ||
            owner != widget.userId ||
            repository != widget.repository) {
          return;
        }
        await _load();
      } else {
        final target = await repository.resolve(
          notice.id,
          generation: notice.groupGeneration,
        );
        if (!mounted ||
            owner != widget.userId ||
            repository != widget.repository) {
          return;
        }
        final route = target == null ? null : studentNoticeTargetRoute(target);
        if (route == null) {
          setState(
            () => _error = 'Este contenido ya no está disponible. El aviso se conserva sin marcar como leído.',
          );
          return;
        }
        await _openRoute(route);
      }
    } catch (_) {
      if (mounted &&
          owner == widget.userId &&
          repository == widget.repository) {
        setState(
          () => _error = acknowledge
              ? 'No se pudo marcar el aviso como leído. Reintenta cuando tengas conexión.'
              : 'No se pudo abrir el contenido. El aviso sigue sin marcar como leído.',
        );
      }
    } finally {
      if (mounted &&
          owner == widget.userId &&
          repository == widget.repository) {
        setState(() => _action = null);
      }
    }
  }

  @override
  void dispose() {
    _request++;
    unawaited(_push?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SectionRefreshBoundary(
    location: '/my-trainer',
    onVisible: _load,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mi preparador'),
        actions: const [AppAccountActions()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openRoute('/directory'),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Buscar preparador'),
                  ),
                ),
                const StudentPushSettings(),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reintentar seguimiento'),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Resumen'),
                      selected: !_showNotices,
                      onSelected: (_) => _selectView(false),
                    ),
                    ChoiceChip(
                      label: Text(
                        _data?.unreadCount == null || _data!.unreadCount == 0
                            ? 'Avisos'
                            : 'Avisos · ${_data!.unreadCount}',
                      ),
                      selected: _showNotices,
                      onSelected: (_) => _selectView(true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_showNotices) ...[
                  if (_data case final data?)
                    ProfessionalResources(
                      resources: data.resources,
                      onOpen: _openRoute,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openRoute('/profile/trainer'),
                      icon: const Icon(Icons.person_outline),
                      label: const Text(
                        'Vínculo e historial con mi preparador',
                      ),
                    ),
                  ),
                  if (!_busy && _data?.resources.hasContent == false)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aquí aparecerá el contenido que recibas. Puedes consultar tus vínculos actuales y anteriores sin perder el historial.',
                      ),
                    ),
                ],
                if (_showNotices)
                  if (_data case final data?) ...[
                    Text(
                      'Avisos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${data.unreadCount} sin leer'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in [null, ...StudentNoticeKind.values])
                          ChoiceChip(
                            label: Text(_kindLabel(kind)),
                            selected: _kind == kind,
                            onSelected: _busy
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
                    const SizedBox(height: 12),
                    if (!_busy && _items.isEmpty)
                      const Text('No hay avisos en esta categoría.'),
                    for (final item in _items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (item.trainerName case final name?) Text(name),
                              if (item.eventCount > 1)
                                Text(
                                  item.newCount > 0
                                      ? '${item.newCount} novedades pendientes · ${item.eventCount} en el historial'
                                      : '${item.eventCount} novedades en el historial',
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${_kindLabel(item.kind)} · ${_day(item.createdAt.toLocal())} · ${item.readAt == null ? 'Sin leer' : 'Leído'}',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: _action != null
                                        ? null
                                        : () => _noticeAction(
                                            item,
                                            acknowledge: false,
                                          ),
                                    child: const Text('Abrir contenido'),
                                  ),
                                  if (item.readAt == null)
                                    TextButton(
                                      onPressed: _action != null
                                          ? null
                                          : () => _noticeAction(
                                              item,
                                              acknowledge: true,
                                            ),
                                      child: const Text('Marcar como leído'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (data.hasMore && _items.isNotEmpty)
                      TextButton(
                        onPressed: _busy ? null : () => _load(more: true),
                        child: const Text('Cargar avisos anteriores'),
                      ),
                  ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _kindLabel(StudentNoticeKind? kind) => switch (kind) {
  null => 'Todos',
  StudentNoticeKind.message => 'Mensajes',
  StudentNoticeKind.form => 'Formularios',
  StudentNoticeKind.assessment => 'Pruebas',
  StudentNoticeKind.techniqueFeedback => 'Técnica',
  StudentNoticeKind.assignment => 'Pautas',
  StudentNoticeKind.appointment => 'Citas',
};
