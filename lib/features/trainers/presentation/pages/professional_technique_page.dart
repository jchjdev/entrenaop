import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/features/workouts/data/services/client_technique_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_technique_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/student_notice_repository.dart';

class ProfessionalTechniqueIndexPage extends StatefulWidget {
  const ProfessionalTechniqueIndexPage({
    super.key,
    required this.repository,
    required this.userId,
  });
  final StudentNoticeRepository repository;
  final String userId;

  @override
  State<ProfessionalTechniqueIndexPage> createState() =>
      _ProfessionalTechniqueIndexPageState();
}

class _ProfessionalTechniqueIndexPageState
    extends State<ProfessionalTechniqueIndexPage>
    with WidgetsBindingObserver {
  List<TechniqueTarget> _items = [];
  bool _busy = true, _more = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfessionalTechniqueIndexPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.repository != widget.repository) {
      _items = [];
      _more = false;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (GoRouter.maybeOf(context)?.state.uri.path ??
                '/my-trainer/technique') ==
            '/my-trainer/technique') {
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
      final page = await widget.repository.listTechnique(
        before: more ? _items.last : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items = more ? [..._items, ...page.items] : page.items;
        _more = page.hasMore;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'No se pudieron actualizar tus sesiones de técnica.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
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
    location: '/my-trainer/technique',
    onVisible: _load,
    child: Scaffold(
      appBar: AppBar(title: const Text('Técnica de mis sesiones')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Elige una sesión de tu preparador para enviar un vídeo o consultar sus respuestas.',
                ),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reintentar sesiones'),
                  ),
                ],
                if (!_busy && _error == null && _items.isEmpty)
                  const Text(
                    'Aún no has iniciado ninguna sesión de tu preparador.',
                  ),
                for (final item in _items)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: Text(item.sessionName),
                      subtitle: Text(_date(item.startedAt.toLocal())),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/my-trainer/technique/${Uri.encodeComponent(item.executionId)}',
                      ),
                    ),
                  ),
                if (_more && _items.isNotEmpty)
                  TextButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: const Text('Cargar sesiones anteriores'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProfessionalTechniquePage extends StatefulWidget {
  const ProfessionalTechniquePage({
    super.key,
    required this.userId,
    required this.executionId,
    required this.workouts,
    required this.technique,
  });
  final String userId, executionId;
  final WorkoutRepository workouts;
  final ClientTechniqueRepository technique;

  @override
  State<ProfessionalTechniquePage> createState() =>
      _ProfessionalTechniquePageState();
}

class _ProfessionalTechniquePageState extends State<ProfessionalTechniquePage>
    with WidgetsBindingObserver {
  WorkoutExecution? _execution;
  bool _busy = true;
  String? _error;
  int _request = 0, _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfessionalTechniquePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.executionId != widget.executionId ||
        oldWidget.workouts != widget.workouts ||
        oldWidget.technique != widget.technique) {
      _execution = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (GoRouter.maybeOf(context)?.state.uri.path ??
                '/my-trainer/technique/${widget.executionId}') ==
            '/my-trainer/technique/${widget.executionId}') {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final executionId = widget.executionId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // La ruta no concede acceso: se verifica la pauta profesional propia antes
      // de consultar resultados o montar cualquier control de medios.
      final data = await widget.technique.context(executionId);
      if (!mounted || request != _request) return;
      if (data == null || data.executionId != executionId) {
        setState(() {
          _execution = null;
          _error = 'Esta sesión no tiene un seguimiento de técnica disponible para tu cuenta.';
        });
        return;
      }
      final execution = await widget.workouts.getExecution(executionId);
      if (!mounted || request != _request) return;
      setState(() {
        _execution = execution?.id == executionId ? execution : null;
        _error = _execution == null
            ? 'No se pudo encontrar esta sesión.'
            : null;
        _version++;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'No se pudo actualizar la técnica de esta sesión.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Técnica con mi preparador')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Reintentar técnica'),
                ),
              ],
              if (_execution case final execution?) ...[
                Text(
                  execution.templateName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(_date(execution.startedAt.toLocal())),
                const SizedBox(height: 12),
                WorkoutTechniqueSection(
                  key: ValueKey('${widget.userId}-${execution.id}-$_version'),
                  execution: execution,
                  repository: widget.technique,
                ),
                if (execution.status != WorkoutExecutionStatus.inProgress)
                  TextButton(
                    onPressed: () => context.push(
                      '/assessment/history/workouts/${Uri.encodeComponent(execution.id)}',
                    ),
                    child: const Text('Ver resultados de la sesión'),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
