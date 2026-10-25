import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_agenda_page.dart';
import 'trainer_calendar_date.dart';
import 'trainer_operations_repository.dart';

class TrainerHomePage extends StatefulWidget {
  const TrainerHomePage({
    super.key,
    required this.access,
    required this.agenda,
    required this.operations,
    this.now,
  });
  final TrainerRepository access;
  final TrainerAgendaRepository agenda;
  final TrainerOperationsRepository operations;
  final DateTime? now;
  @override
  State<TrainerHomePage> createState() => _TrainerHomePageState();
}

class _TrainerHomePageState extends State<TrainerHomePage> {
  TrainerAccess? _access;
  List<TrainerReviewItem> _reviews = [];
  List<TrainerAgendaItem> _upcoming = [];
  bool _busy = true;
  String? _error;
  late final DateTime _today = DateUtils.dateOnly(widget.now ?? DateTime.now());
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Cada lectura conserva su autorización; la portada no abre otros historiales.
      final access = await widget.access.access();
      final reviews = await widget.operations.reviews();
      final agenda = await widget.agenda.range(
        _today,
        DateTime(_today.year, _today.month, _today.day + 6),
      );
      if (mounted) {
        setState(() {
          _access = access;
          _reviews = reviews;
          _upcoming = agenda;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tu jornada como preparador'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1100,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (_access case final access?) ...[
              Text(
                access.status,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${access.activeClients}/${access.limit} plazas de alumnos activos',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/clients'),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Gestionar alumnos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/agenda'),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Abrir agenda'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/reviews'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Revisar resultados'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ProfessionalCatalogGrid(
                minCardWidth: 420,
                maxColumns: 2,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Resultados por revisar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${_reviews.length} cargados${_reviews.length == 100 ? ' · listado parcial, abre la bandeja para continuar' : ''}',
                          ),
                          if (_reviews.isEmpty && !_busy)
                            const Text(
                              'No hay resultados pendientes de revisión.',
                            ),
                          for (final review in _reviews.take(5))
                            Card(
                              child: ListTile(
                                title: Text(review.clientName),
                                subtitle: Text(review.assignment.name),
                                onTap: () async {
                                  await context.push(
                                    '/clients/${review.clientId}/workouts/${review.assignment.id}/result',
                                  );
                                  if (mounted) await _load();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Próximos siete días',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${_upcoming.length} pautas cargadas${_upcoming.length == 100 ? ' · agenda parcial' : ''}',
                          ),
                          if (_upcoming.isEmpty && !_busy)
                            const Text('No hay pautas en este periodo.'),
                          for (final item in _upcoming.take(10))
                            Card(
                              child: ListTile(
                                title: Text(
                                  '${item.clientName} · ${item.assignment.name}',
                                ),
                                subtitle: Text(
                                  '${trainerCalendarDate(item.assignment.date)} · ${item.assignment.statusLabel}',
                                ),
                                onTap: () => context.push(
                                  '/clients/${item.clientId}/workouts',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
