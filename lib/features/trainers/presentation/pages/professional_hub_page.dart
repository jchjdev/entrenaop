import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/student_notice_repository.dart';
import '../widgets/professional_resources.dart';

String? studentNoticeTargetRoute(StudentNoticeTarget target) {
  final id = Uri.encodeComponent(target.targetId);
  return switch (target.kind) {
    StudentNoticeTargetKind.conversation => '/my-trainer/conversations/$id',
    StudentNoticeTargetKind.form => '/my-trainer/forms/$id',
    StudentNoticeTargetKind.assessment => '/my-trainer/assessments/$id',
    StudentNoticeTargetKind.technique => '/my-trainer/technique/$id',
    StudentNoticeTargetKind.workout =>
      target.scheduledDate == null
          ? null
          : '/plan/week?date=${_day(target.scheduledDate!)}&session=$id',
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
  });
  final StudentNoticeRepository repository;
  final String userId;
  final Future<void> Function(String)? onOpen;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfessionalHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      setState(() {
        _data = data;
        _items = more ? [..._items, ...data.items] : data.items;
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
        await repository.ack(notice.id);
        if (!mounted ||
            owner != widget.userId ||
            repository != widget.repository) {
          return;
        }
        await _load();
      } else {
        final target = await repository.resolve(notice.id);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SectionRefreshBoundary(
    location: '/my-trainer',
    onVisible: _load,
    child: Scaffold(
      appBar: AppBar(title: const Text('Con mi preparador')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reintentar seguimiento'),
                  ),
                ],
                if (_data case final data?) ...[
                  if (data.resources.hasContent) ...[
                    ProfessionalResources(
                      resources: data.resources,
                      onOpen: _openRoute,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openRoute('/profile/trainer'),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Ver vínculo con mi preparador'),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                  ] else if (!_busy)
                    const Text(
                      'No tienes contenido de un preparador. Tus sesiones y preparaciones siguen en Inicio.',
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
};
