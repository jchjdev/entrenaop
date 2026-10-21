import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/trainer_access.dart';

class AdminTrainerAccessCard extends StatefulWidget {
  const AdminTrainerAccessCard({
    super.key,
    required this.repository,
    required this.userId,
  });
  final TrainerRepository repository;
  final String userId;
  @override
  State<AdminTrainerAccessCard> createState() => _AdminTrainerAccessCardState();
}

class _AdminTrainerAccessCardState extends State<AdminTrainerAccessCard> {
  final _limit = TextEditingController(), _reason = TextEditingController();
  TrainerManagement? _management;
  TrainerAccessChange? _pending;
  bool _busy = true, _enabled = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _limit.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _management = null;
    });
    try {
      final management = await widget.repository.management(widget.userId);
      if (!mounted) return;
      setState(() {
        _management = management;
        _pending = null;
        _enabled = management.access.enabled;
        _limit.text = management.access.limit == 0
            ? ''
            : '${management.access.limit}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _management?.enabled != true) return;
    final access = _management!.access;
    if (_pending == null) {
      final limit = int.tryParse(_limit.text.trim());
      final reason = _reason.text.trim();
      if (limit == null ||
          limit < 1 ||
          reason.length < 3 ||
          reason.length > 500) {
        setState(
          () => _error =
              'Indica un cupo positivo y un motivo de 3 a 500 caracteres.',
        );
        return;
      }
      final change = TrainerAccessChange(
        trainerId: widget.userId,
        limit: limit,
        enabled: _enabled,
        revision: access.revision,
        reason: reason,
        validUntil: access.validUntil,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: const Text('Cambiar acceso profesional'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${change.enabled ? 'Habilitar' : 'Retirar'} acceso con ${change.limit} plazas. Pro personal se mantiene por separado. Los vínculos existentes se conservan. No se realiza ningún cobro.',
              ),
              const SizedBox(height: 20),
              EntrenaDialogActions(
                primaryLabel: 'Confirmar',
                onPrimary: () => Navigator.pop(context, true),
                secondary: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ],
          ),
          actions: const [],
        ),
      );
      if (confirmed != true || !mounted || _busy) return;
      _pending = change;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.changeAccess(_pending!);
      if (!mounted) return;
      _pending = null;
      _reason.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && _management?.enabled == true && _pending == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acceso profesional',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Permite gestionar clientes con un cupo propio. No concede permisos administrativos ni Pro personal.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!),
              ),
            if (_management case final management?) ...[
              const SizedBox(height: 12),
              Text(management.access.status),
              Text(
                '${management.access.activeClients} clientes activos · Cupo ${management.access.limit}',
              ),
              if (management.access.validUntil != null)
                Text(
                  'Vigencia existente: ${trainerDate(management.access.validUntil!)}',
                ),
              if (!management.enabled)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'La gestión profesional está deshabilitada en este entorno. El piloto todavía no está habilitado.',
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Habilitar acceso profesional'),
                value: _enabled,
                onChanged: editable
                    ? (v) => setState(() => _enabled = v)
                    : null,
              ),
              TextField(
                controller: _limit,
                enabled: editable,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cupo de alumnos activos',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: editable,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio profesional',
                ),
              ),
              if (_pending != null)
                const Text(
                  'Hay una petición sin confirmar. Reintenta la misma operación o actualiza para consultar su estado.',
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || !management.enabled ? null : _save,
                child: Text(
                  _pending == null
                      ? 'Guardar acceso profesional'
                      : 'Reintentar el mismo cambio',
                ),
              ),
            ],
            TextButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar acceso profesional'),
            ),
          ],
        ),
      ),
    );
  }
}
