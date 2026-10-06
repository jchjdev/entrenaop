import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import '../../domain/entities/training_context.dart';
import '../../domain/repositories/training_context_repository.dart';
import '../widgets/training_context_fields.dart';

class TrainingContextPage extends StatefulWidget {
  const TrainingContextPage({required this.repository, super.key});
  final TrainingContextRepository repository;
  @override
  State<TrainingContextPage> createState() => _TrainingContextPageState();
}

class _TrainingContextPageState extends State<TrainingContextPage> {
  TrainingContextSettings? _settings;
  final _availability = <String, int>{};
  final _equipment = <String>{};
  bool _pain = false, _confirmed = false, _saving = false;
  String? _error;
  String? _savedStamp;
  String get _stamp => jsonEncode([
    (_availability.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => [e.key, e.value])
        .toList(),
    _equipment.toList()..sort(),
    _pain,
    _confirmed,
  ]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        final current = settings.context;
        if (current != null) {
          _availability.addAll(current.availability);
          _equipment.addAll(current.equipment);
          _pain = current.reportsPain;
          _confirmed = current.capacityConfirmed;
        } else {
          _pain = settings.previousReportsLimitation;
          if (settings.previousPullUpBar) _equipment.add('pull_up_bar');
        }
        _error = null;
        _savedStamp = _stamp;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No hemos podido cargar tu disponibilidad. Vuelve a intentarlo.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_availability.values.any((minutes) => minutes > 0)) {
      setState(() => _error = 'Selecciona al menos un día disponible.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        TrainingContext(
          availability: _availability,
          equipment: _equipment,
          reportsPain: _pain,
          capacityConfirmed: _confirmed,
        ),
      );
      _savedStamp = _stamp;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Disponibilidad y material guardados. Tu programa usará estos datos en la siguiente adaptación.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No hemos podido guardar los datos. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _settings != null && _savedStamp != _stamp,
    isBusy: () => _saving,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Disponibilidad y material')),
    body: _settings == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'El mismo contexto para tu programa',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estos datos son compartidos con «Mi programa». Actualizarlos no reinicia tus entrenamientos ni borra resultados.',
                    ),
                    if (_settings!.context == null &&
                        _settings!.previousDaysPerWeek != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Antes indicabas ${_settings!.previousDaysPerWeek} días de ${_settings!.previousSessionMinutes} min. Elige ahora los días concretos y confirma el material que tienes.',
                      ),
                    ],
                    const SizedBox(height: 20),
                    TrainingContextFields(
                      availability: _availability,
                      equipment: _equipment,
                      equipmentOptions: _settings!.equipmentOptions,
                      reportsPain: _pain,
                      confirmed: _confirmed,
                      enabled: !_saving,
                      defaultMinutes: _settings!.previousSessionMinutes ?? 60,
                      onAvailability: (day, minutes) =>
                          setState(() => _availability[day] = minutes),
                      onEquipment: (code, selected) => setState(() {
                        selected
                            ? _equipment.add(code)
                            : _equipment.remove(code);
                      }),
                      onPain: (value) => setState(() => _pain = value),
                      onConfirmed: (value) =>
                          setState(() => _confirmed = value),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Guardando…'
                            : 'Guardar disponibilidad y material',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
