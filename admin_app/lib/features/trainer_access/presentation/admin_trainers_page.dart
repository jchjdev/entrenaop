import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'admin_trainer_access_card.dart';

class AdminTrainersPage extends StatefulWidget {
  const AdminTrainersPage({super.key, required this.repository});
  final TrainerRepository repository;
  @override
  State<AdminTrainersPage> createState() => _AdminTrainersPageState();
}

class _AdminTrainersPageState extends State<AdminTrainersPage> {
  List<ManagedTrainer> _trainers = [];
  ManagedTrainer? _selected;
  bool _busy = true, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.managedTrainers(
        afterId: more ? _trainers.last.id : null,
      );
      if (mounted) {
        setState(() {
          _trainers = more ? [..._trainers, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trainers = [];
          _error = trainerError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Entrenadores')),
    body: Center(
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 760,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextButton.icon(
              onPressed: () => context.go('/accounts'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Cuentas registradas'),
            ),
            Text(
              'Accesos profesionales',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta el cupo y administra el acceso. Para habilitar una cuenta nueva, abre su ficha en Cuentas registradas.',
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_selected case final trainer?) ...[
              Text(trainer.email),
              AdminTrainerAccessCard(
                key: ValueKey(trainer.id),
                repository: widget.repository,
                userId: trainer.id,
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selected = null);
                  _load();
                },
                child: const Text('Volver a los entrenadores'),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar entrenadores'),
              ),
              if (!_busy && _error == null && _trainers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay accesos profesionales concedidos.',
                    ),
                  ),
                ),
              for (final trainer in _trainers)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(trainer.name),
                    subtitle: Text(
                      '${trainer.email}\n${trainer.status} · ${trainer.activeClients}/${trainer.limit} alumnos',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => setState(() => _selected = trainer),
                  ),
                ),
              if (_more)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Más entrenadores'),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
