import 'package:trainer_access/trainer_calendar.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import '../domain/coach_workspace_repository.dart';
import 'coach_workspace_scope.dart';

String coachDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String coachClientRoute(String id) =>
    '/coach/clients/${Uri.encodeComponent(id)}';
String coachAssignmentRoute(String id) =>
    '/coach/assignment/${Uri.encodeComponent(id)}';

class CoachLoad<T> extends StatefulWidget {
  const CoachLoad({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;
  @override
  State<CoachLoad<T>> createState() => _CoachLoadState<T>();
}

class _CoachLoadState<T> extends State<CoachLoad<T>> {
  late Future<T> _future = widget.load();
  void _refresh() {
    if (!mounted) return;
    final future = widget.load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trainerError(snapshot.error!)),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snapshot.data as T, _refresh);
    },
  );
}

class CoachPagedList<T> extends StatefulWidget {
  const CoachPagedList({
    super.key,
    required this.title,
    required this.load,
    required this.row,
    required this.pageSize,
    this.header,
    this.filter,
    this.empty = 'No hay elementos.',
    this.embedded = false,
    this.refreshParent,
  });
  final String title, empty;
  final Future<List<T>> Function(T? before) load;
  final Widget Function(BuildContext, T) row;
  final bool Function(T, String)? filter;
  final int pageSize;
  final Widget? header;
  final bool embedded;
  final VoidCallback? refreshParent;
  @override
  State<CoachPagedList<T>> createState() => _CoachPagedListState<T>();
}

class _CoachPagedListState<T> extends State<CoachPagedList<T>> {
  final List<T> _items = [];
  bool _loading = false, _more = true, _retryRefresh = false;
  String? _error;
  String _query = '';
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    final generation = ++_generation;
    _retryRefresh = refresh;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.load(
        refresh || _items.isEmpty ? null : _items.last,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (refresh) _items.clear();
        _items.addAll(rows);
        _more = rows.length == widget.pageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: () async {
        if (widget.refreshParent != null) {
          widget.refreshParent!();
        } else {
          await _load(refresh: true);
        }
      },
      child: _list(context),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(refresh: true),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _list(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      if (widget.header != null) widget.header!,
      if (widget.filter != null) ...[
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar entre los alumnos cargados',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
      ],
      if (_error != null) ...[
        Text(_error!),
        TextButton(
          onPressed: () => _load(refresh: _retryRefresh),
          child: const Text('Reintentar'),
        ),
      ],
      if (_loading) const LinearProgressIndicator(),
      for (final item in _items)
        if (widget.filter == null || widget.filter!(item, _query))
          widget.row(context, item),
      if (_items.isEmpty && !_loading && _error == null)
        Padding(padding: const EdgeInsets.all(24), child: Text(widget.empty)),
      if (_more && !_loading && _error == null)
        TextButton(onPressed: _load, child: const Text('Cargar más')),
    ],
  );
}

class CoachSummaryPage extends StatelessWidget {
  const CoachSummaryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    final repo = scope.controller.repository;
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Tu seguimiento')),
      body: CoachLoad(
        key: ValueKey(today),
        load: () => (
          repo.agenda(today, today),
          repo.reviews(),
          repo.pendingTechnique(),
        ).wait,
        builder: (context, data, refresh) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hoy · ${coachDate(today)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Badge.count(
                  count: scope.controller.unread,
                  isLabelVisible: scope.controller.unread > 0,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                title: const Text('Mensajes de tus alumnos'),
                subtitle: Text(
                  scope.controller.unread > 0
                      ? '${scope.controller.unread} sin leer'
                      : 'Sin mensajes pendientes',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/coach/messages'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Entrenamientos de hoy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.$1.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes pautas para hoy.'),
              ),
            for (final item in data.$1.take(5)) CoachAssignmentTile(item: item),
            TextButton(
              onPressed: () => context.go('/coach/agenda'),
              child: const Text('Abrir agenda completa'),
            ),
            const SizedBox(height: 16),
            Text(
              'Resultados pendientes de revisar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.$2.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay resultados pendientes.'),
              ),
            for (final item in data.$2.take(5)) CoachAssignmentTile(item: item),
            TextButton(
              onPressed: () => context.push('/coach/reviews'),
              child: const Text('Ver todas las revisiones'),
            ),
            Text(
              'Vídeos sin corrección',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (data.$3.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay vídeos compartidos pendientes de una primera corrección.',
                ),
              ),
            for (final clip in data.$3.take(5)) CoachTechniqueTile(item: clip),
            TextButton(
              onPressed: () => context.push('/coach/videos'),
              child: const Text('Ver todos los vídeos sin corrección'),
            ),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar resumen'),
            ),
          ],
        ),
      ),
    );
  }
}

class CoachAssignmentTile extends StatelessWidget {
  const CoachAssignmentTile({super.key, required this.item});
  final CoachAssignment item;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        item.status == 'completed' ? Icons.task_alt : Icons.fitness_center,
      ),
      title: Text(item.name),
      subtitle: Text(
        '${item.clientName.isEmpty ? '' : '${item.clientName} · '}${coachDate(item.date)} · ${item.statusLabel}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(coachAssignmentRoute(item.id)),
    ),
  );
}

class CoachAgendaPage extends StatefulWidget {
  const CoachAgendaPage({super.key});
  @override
  State<CoachAgendaPage> createState() => _CoachAgendaPageState();
}

class _CoachAgendaPageState extends State<CoachAgendaPage> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _week = false;
  @override
  Widget build(BuildContext context) {
    final from = _week ? _day.subtract(Duration(days: _day.weekday - 1)) : _day;
    final to = _week ? from.add(const Duration(days: 6)) : from;
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    return CoachPagedList<CoachAssignment>(
      key: ValueKey(('agenda', from, to)),
      title: 'Agenda de alumnos',
      pageSize: 100,
      load: (after) => repo.agenda(from, to, after: after),
      row: (_, item) => CoachAssignmentTile(item: item),
      empty: 'No hay pautas en estas fechas.',
      header: Column(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Día')),
              ButtonSegment(value: true, label: Text('Semana')),
            ],
            selected: {_week},
            onSelectionChanged: (v) => setState(() => _week = v.single),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _day = _day.subtract(Duration(days: _week ? 7 : 1)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2200),
                    );
                    if (picked != null && mounted) {
                      setState(() => _day = picked);
                    }
                  },
                  child: Text(
                    _week
                        ? '${coachDate(from)} – ${coachDate(to)}'
                        : coachDate(_day),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                  () => _day = _day.add(Duration(days: _week ? 7 : 1)),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () =>
                setState(() => _day = DateUtils.dateOnly(DateTime.now())),
            child: const Text('Hoy'),
          ),
        ],
      ),
    );
  }
}

class CoachClientsPage extends StatefulWidget {
  const CoachClientsPage({super.key, this.messages = false});
  final bool messages;
  @override
  State<CoachClientsPage> createState() => _CoachClientsPageState();
}

class _CoachClientsPageState extends State<CoachClientsPage> {
  TrainerClientState _state = TrainerClientState.active;
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    return CoachPagedList<TrainerClient>(
      key: ValueKey((widget.messages, _state)),
      title: widget.messages ? 'Mensajes' : 'Tus alumnos',
      pageSize: 50,
      load: (before) =>
          scope.controller.repository.clients(state: _state, before: before),
      filter: (item, query) => item.name.toLowerCase().contains(query),
      empty: 'No hay alumnos en este estado.',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          spacing: 8,
          children: [
            for (final state in TrainerClientState.values)
              ChoiceChip(
                label: Text(switch (state) {
                  TrainerClientState.active => 'Activos',
                  TrainerClientState.inactive => 'Inactivos',
                  TrainerClientState.archived => 'Archivados',
                }),
                selected: _state == state,
                onSelected: (_) => setState(() => _state = state),
              ),
          ],
        ),
      ),
      row: (context, item) {
        final unread = scope.controller.inbox?.clients[item.personId];
        return Card(
          child: ListTile(
            leading: Badge.count(
              count: unread?.unreadCount ?? 0,
              isLabelVisible: (unread?.unreadCount ?? 0) > 0,
              child: Icon(
                widget.messages
                    ? Icons.chat_bubble_outline
                    : Icons.person_outline,
              ),
            ),
            title: Text(item.name),
            subtitle: Text(
              (unread?.unreadCount ?? 0) > 0
                  ? '${unread!.unreadCount} mensajes sin leer'
                  : item.active
                  ? 'Servicio activo'
                  : 'Servicio inactivo',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final relation = unread?.relationId ?? item.activeRelationId;
              if (widget.messages && relation != null) {
                context.push(
                  '/coach/messages/${Uri.encodeComponent(relation)}',
                );
              } else {
                context.push(coachClientRoute(item.personId));
              }
            },
          ),
        );
      },
    );
  }
}

class CoachClientPage extends StatelessWidget {
  const CoachClientPage({super.key, required this.clientId});
  final String clientId;
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    return CoachLoad(
      load: () => repo.client(clientId),
      builder: (context, data, refresh) => CoachPagedList<CoachAssignment>(
        title: data.client.name,
        pageSize: 50,
        load: (before) => repo.assignments(clientId, before: before),
        row: (_, item) => CoachAssignmentTile(item: item),
        empty: 'Todavía no hay sesiones de tu servicio.',
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.client.activeRelationId case final relation?)
              FilledButton.icon(
                onPressed: () => context.push(
                  '/coach/messages/${Uri.encodeComponent(relation)}',
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Conversación'),
              ),
            TextButton.icon(
              onPressed: () => context.push(
                '/coach/client-history/${Uri.encodeComponent(clientId)}',
              ),
              icon: const Icon(Icons.history),
              label: const Text('Conversaciones de etapas anteriores'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/coach/calendar/${Uri.encodeComponent(clientId)}',
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Calendario compartido'),
            ),
            Text(
              'Objetivo de oposición',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              data.goal.title.isEmpty
                  ? 'Todavía no has definido un objetivo en Trainer web.'
                  : data.goal.title,
            ),
            if (data.goal.targetDate != null)
              Text('Fecha objetivo: ${coachDate(data.goal.targetDate!)}'),
            for (final target in data.goal.targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(target.protocol.name),
                subtitle: Text(
                  'Objetivo: ${_goalMark(target.value, target.protocol.unit)} · Última: ${target.hasLatestEvidence && target.latest != null ? _goalMark(target.latest!, target.protocol.unit) : 'Sin marca compatible'}',
                ),
                trailing: target.reached == null
                    ? null
                    : Icon(
                        target.reached! ? Icons.task_alt : Icons.flag_outlined,
                      ),
              ),
            const SizedBox(height: 16),
            Text(
              'Planificación y resultados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: refresh,
              child: const Text('Actualizar ficha'),
            ),
          ],
        ),
      ),
    );
  }
}

class CoachReviewsPage extends StatelessWidget {
  const CoachReviewsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    return CoachPagedList<CoachAssignment>(
      title: 'Resultados pendientes',
      pageSize: 100,
      load: (before) => repo.reviews(before: before),
      row: (_, item) => CoachAssignmentTile(item: item),
      empty: 'No hay resultados pendientes.',
    );
  }
}

String _goalMark(double value, ProfessionalMarkUnit unit) => switch (unit) {
  ProfessionalMarkUnit.seconds => formatPerformanceTime(value),
  ProfessionalMarkUnit.repetitions => '${value.toInt()} rep',
  ProfessionalMarkUnit.meters =>
    '${value.toString().replaceFirst(RegExp(r'\.0$'), '')} m',
};

class CoachTechniqueTile extends StatelessWidget {
  const CoachTechniqueTile({super.key, required this.item});
  final CoachTechniquePending item;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.video_library_outlined),
      title: Text(item.clientName),
      subtitle: Text('${item.name} · ${coachDate(item.createdAt.toLocal())}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(
        '/coach/technique/${Uri.encodeComponent(item.assignmentId)}',
      ),
    ),
  );
}

class CoachPendingTechniquePage extends StatelessWidget {
  const CoachPendingTechniquePage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    return CoachPagedList<CoachTechniquePending>(
      title: 'Vídeos sin corrección',
      pageSize: 50,
      load: (before) => repo.pendingTechnique(before: before),
      row: (_, item) => CoachTechniqueTile(item: item),
      empty: 'No hay vídeos pendientes de una primera corrección.',
    );
  }
}

class CoachSharedCalendarPage extends StatefulWidget {
  const CoachSharedCalendarPage({super.key, required this.clientId});
  final String clientId;
  @override
  State<CoachSharedCalendarPage> createState() =>
      _CoachSharedCalendarPageState();
}

class _CoachSharedCalendarPageState extends State<CoachSharedCalendarPage> {
  int _reload = 0;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    final from = _day.subtract(Duration(days: _day.weekday - 1));
    final to = from.add(const Duration(days: 6));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario compartido'),
        actions: [
          IconButton(
            tooltip: 'Actualizar calendario',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _reload++),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _day = _day.subtract(const Duration(days: 7)),
                ),
              ),
              Expanded(
                child: Text(
                  '${coachDate(from)} – ${coachDate(to)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => _day = _day.add(const Duration(days: 7))),
              ),
            ],
          ),
          Expanded(
            child: CoachLoad(
              key: ValueKey((widget.clientId, from, _reload)),
              load: () => repo.sharedCalendar(widget.clientId, from, to),
              builder: (context, page, refresh) => !page.shared
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'El alumno no tiene activada la compartición del calendario con este servicio.',
                        ),
                      ),
                    )
                  : CoachPagedList<SharedCalendarEntry>(
                      title: 'Semana del alumno',
                      embedded: true,
                      refreshParent: refresh,
                      pageSize: 50,
                      header: Column(
                        children: [
                          const Text(
                            'Solo consulta. El calendario compartido no permite acceder a resultados ni conversaciones de otros preparadores.',
                          ),
                          if (page.coaches.isNotEmpty)
                            Text(page.coaches.join(' · ')),
                        ],
                      ),
                      load: (after) async => after == null
                          ? page.entries
                          : (await repo.sharedCalendar(
                              widget.clientId,
                              from,
                              to,
                              after: after,
                            )).entries,
                      row: (_, item) => Card(
                        child: ListTile(
                          leading: Icon(
                            item.running
                                ? Icons.directions_run
                                : Icons.fitness_center,
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${coachDate(item.date)} · ${item.trainerName ?? 'Plan personal'}',
                          ),
                          trailing: item.own
                              ? const Icon(Icons.chevron_right)
                              : null,
                          onTap: item.own
                              ? () =>
                                    context.push(coachAssignmentRoute(item.id))
                              : null,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoachClientHistoryPage extends StatelessWidget {
  const CoachClientHistoryPage({super.key, required this.clientId});
  final String clientId;
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).controller.repository;
    return CoachPagedList<TrainerRelation>(
      title: 'Historial del servicio',
      pageSize: 50,
      load: (before) => repo.relations(clientId, before: before),
      row: (context, item) => Card(
        child: ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text('Desde ${coachDate(item.acceptedAt)}'),
          subtitle: Text(
            item.endedAt == null
                ? 'Etapa activa'
                : 'Finalizada el ${coachDate(item.endedAt!)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.push('/coach/messages/${Uri.encodeComponent(item.id)}'),
        ),
      ),
    );
  }
}
