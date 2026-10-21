import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import 'trainer_groups_repository.dart';
import 'trainer_workout_repository.dart';

Future<bool?> showTrainerWeekCopyDialog(
  BuildContext context,
  TrainerGroupsRepository repository,
  DateTime weekStart,
  int offsetDays,
) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _TrainerWeekCopyDialog(
    repository: repository,
    weekStart: weekStart,
    offsetDays: offsetDays,
  ),
);

class _TrainerWeekCopyDialog extends StatefulWidget {
  const _TrainerWeekCopyDialog({
    required this.repository,
    required this.weekStart,
    required this.offsetDays,
  });
  final TrainerGroupsRepository repository;
  final DateTime weekStart;
  final int offsetDays;
  @override
  State<_TrainerWeekCopyDialog> createState() => _TrainerWeekCopyDialogState();
}

class _TrainerWeekCopyDialogState extends State<_TrainerWeekCopyDialog> {
  TrainerWeekCopyPreview? _preview;
  TrainerWeekCopyReceipt? _receipt;
  String? _operationId, _error;
  bool _busy = true, _definitive = false;
  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_operationId != null && !_definitive) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _operationId = null;
      _definitive = false;
    });
    try {
      final preview = await widget.repository.previewWeek(
        widget.weekStart,
        widget.offsetDays,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (_busy || preview == null || preview.items.isEmpty || _definitive) {
      return;
    }
    _operationId ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.copyWeek(
        _operationId!,
        widget.weekStart,
        widget.offsetDays,
        preview.fingerprint,
      );
      if (mounted) setState(() => _receipt = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _definitive =
              e is PostgrestException &&
              ['22023', '42501', '40001', '23503', '23514'].contains(e.code);
          _error = _definitive
              ? 'La copia no se ha realizado. ${trainerError(e)} Vuelve a revisar la semana.'
              : 'No se ha podido confirmar la copia. Reintenta esta misma orden; sus fechas y recetas se conservan.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recipe(TrainerWeekCopyItem item) async {
    try {
      final template = await widget.repository.template(item.templateId);
      if (!mounted) return;
      if (template == null) throw StateError('Receta no disponible');
      await showDialog<void>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: Text(item.templateName),
          content: WorkoutTemplateContent(template: template),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver a la copia'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview, receipt = _receipt;
    final names = {
      for (final item in preview?.items ?? <TrainerWeekCopyItem>[])
        item.clientId: item.clientName,
    };
    return PopScope(
      canPop: !_busy,
      child: EntrenaDialog(
        title: const Text('Revisar copia de semana'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Semana del ${_date(widget.weekStart)} · desplazamiento de ${widget.offsetDays} días.',
            ),
            const Text(
              'Se añaden citas independientes con la receta fijada. Las originales y el plan automático se conservan. La comprobación abarca toda la semana, no solo lo visible en agenda.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (receipt != null) ...[
              Text(
                'Copia confirmada: ${receipt.assignmentCount} pautas.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final client in receipt.byClient.entries)
                Text(
                  '${names[client.key] ?? 'Alumno'}: ${client.value} ${client.value == 1 ? 'pauta añadida' : 'pautas añadidas'}.',
                ),
            ] else if (preview != null) ...[
              Text(
                '${preview.items.length} pautas para copiar · ${preview.excludedCount} excluidas por estado o vínculo.',
              ),
              if (preview.items.isEmpty)
                const Text(
                  'No hay pautas pendientes de vínculos activos para copiar.',
                ),
              for (final item in preview.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.clientName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(item.templateName),
                        Text('${_date(item.date)} → ${_date(item.targetDate)}'),
                        if (item.hasDateCoincidence)
                          const Text(
                            'Coincide con otra pauta en la fecha destino. Se conservarán ambas.',
                          ),
                        if (item.note?.isNotEmpty == true) Text(item.note!),
                        TextButton(
                          onPressed: _busy ? null : () => _recipe(item),
                          child: const Text('Ver receta fijada'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.pop(context, receipt != null),
            child: Text(receipt == null ? 'Cerrar' : 'Volver a la agenda'),
          ),
          if (receipt == null && (_preview == null || _definitive))
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Volver a revisar'),
            ),
          if (receipt == null &&
              preview != null &&
              preview.items.isNotEmpty &&
              !_definitive)
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: Text(
                _operationId == null
                    ? 'Confirmar ${preview.items.length} pautas'
                    : 'Reintentar misma copia',
              ),
            ),
        ],
      ),
    );
  }
}
