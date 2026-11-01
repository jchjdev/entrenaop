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
  final _suspensionReason = TextEditingController();
  TrainerManagement? _management;
  TrainerAccessChange? _pending;
  TrainerSuspensionChange? _pendingSuspension;
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
    _suspensionReason.dispose();
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
        _pendingSuspension = null;
        _enabled = management.manualEnabled;
        _limit.text = '${management.manualLimit}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _management?.enabled != true || _pendingSuspension != null) {
      return;
    }
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
        validUntil: _management!.manualValidUntil,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: const Text('Cambiar acceso regalado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${change.enabled ? 'Conceder' : 'Retirar'} el acceso regalado de ${change.limit} plazas. Si tiene una suscripción pagada vigente, conservará ese acceso. Esto no levanta una suspensión ni cambia Pro, los vínculos o los cobros.',
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

  Future<void> _suspend() async {
    if (_busy || _management == null || _pending != null) return;
    if (_pendingSuspension == null) {
      _suspensionReason.clear();
      final suspend = !_management!.access.suspended;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => EntrenaDialog(
            title: Text(
              suspend ? 'Suspender entrenador' : 'Reactivar entrenador',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  suspend
                      ? 'Bloquea las funciones profesionales aunque tenga una suscripción pagada. Conserva el historial y su cuenta de deportista. No cancela ni reembolsa los pagos.'
                      : 'Levanta la suspensión. Recuperará el acceso que le corresponda por suscripción o regalo vigente. No concede un nuevo regalo ni reactiva suscripciones vencidas.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _suspensionReason,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Motivo administrativo',
                  ),
                ),
                const SizedBox(height: 16),
                EntrenaDialogActions(
                  primaryLabel: suspend
                      ? 'Confirmar suspensión'
                      : 'Confirmar reactivación',
                  onPrimary: _suspensionReason.text.trim().length >= 3
                      ? () => Navigator.pop(context, true)
                      : null,
                  secondary: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ],
            ),
            actions: const [],
          ),
        ),
      );
      if (confirmed != true || !mounted || _busy) return;
      _pendingSuspension = TrainerSuspensionChange(
        trainerId: widget.userId,
        suspended: suspend,
        revision: _management!.access.revision,
        reason: _suspensionReason.text.trim(),
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.changeSuspension(_pendingSuspension!);
      if (!mounted) return;
      _pendingSuspension = null;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable =
        !_busy &&
        _management?.enabled == true &&
        _pending == null &&
        _pendingSuspension == null;
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
              const SizedBox(height: 12),
              Text(
                'Suspensión profesional',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (management.suspensionReason case final reason?)
                Text('Motivo: $reason'),
              const Text(
                'El bloqueo prevalece sobre regalos y pagos. No borra el historial ni afecta a su cuenta de deportista. Los cobros se gestionan por separado.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed:
                    _busy || _pending != null || management.access.revision == 0
                    ? null
                    : _suspend,
                icon: Icon(
                  management.access.suspended ? Icons.lock_open : Icons.block,
                ),
                label: Text(
                  _pendingSuspension != null
                      ? 'Reintentar suspensión o reactivación'
                      : management.access.suspended
                      ? 'Reactivar entrenador'
                      : 'Suspender entrenador',
                ),
              ),
              if (_pendingSuspension != null)
                const Text(
                  'Hay una operación sin confirmar. Reintenta la misma petición o actualiza para consultar su estado.',
                ),
              const Divider(height: 32),
              Text(
                'Acceso regalado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Esta concesión es independiente de su suscripción pagada. Retirarla no suspende al entrenador.',
              ),
              if (management.manualValidUntil != null)
                Text(
                  'Vigencia del regalo: ${trainerDate(management.manualValidUntil!)}',
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
                title: const Text('Conceder acceso regalado'),
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
                  labelText: 'Plazas del acceso regalado',
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
                onPressed:
                    _busy || !management.enabled || _pendingSuspension != null
                    ? null
                    : _save,
                child: Text(
                  _pending == null
                      ? 'Guardar acceso regalado'
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
