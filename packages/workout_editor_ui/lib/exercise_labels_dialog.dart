import 'package:flutter/material.dart';

import 'exercise_preferences_controller.dart';

class ExerciseLabelFilter extends StatelessWidget {
  const ExerciseLabelFilter({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final Iterable<String> labels;
  final String? selected;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Filtrar por mis etiquetas',
    onSelected: (label) => onChanged(label.isEmpty ? null : label),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Todas las colecciones')),
      for (final label in (labels.toSet().toList()..sort()))
        PopupMenuItem(value: label, child: Text(label)),
    ],
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Text(selected ?? 'Mis colecciones'),
    ),
  );
}

Future<void> editExerciseLabels(
  BuildContext context,
  ExercisePreferencesController preferences,
  String exerciseId,
  String exerciseName,
) => showDialog<void>(
  context: context,
  builder: (_) => _ExerciseLabelsDialog(
    preferences: preferences,
    id: exerciseId,
    name: exerciseName,
  ),
);

class _ExerciseLabelsDialog extends StatefulWidget {
  const _ExerciseLabelsDialog({
    required this.preferences,
    required this.id,
    required this.name,
  });
  final ExercisePreferencesController preferences;
  final String id, name;
  @override
  State<_ExerciseLabelsDialog> createState() => _ExerciseLabelsDialogState();
}

class _ExerciseLabelsDialogState extends State<_ExerciseLabelsDialog> {
  final _text = TextEditingController();
  late final Future<void> _load = _read();
  int _revision = 0;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  ({String operationId, List<String> labels})? _attempt;

  Future<void> _read() async {
    await widget.preferences.refreshLabels();
    if (!mounted) return;
    _revision = widget.preferences.labelsRevision(widget.id);
    _text.text = widget.preferences.labels(widget.id).join(', ');
    setState(() => _ready = true);
  }

  Future<void> _save() async {
    if (_busy || !_ready) return;
    final labels = _text.text.trim().isEmpty
        ? <String>[]
        : _text.text.split(',').map((s) => s.trim()).toList();
    if (labels.length > 8 ||
        labels.any(
          (s) =>
              s.isEmpty ||
              s.runes.length > 32 ||
              RegExp(r'[\x00-\x1f\x7f]').hasMatch(s),
        ) ||
        labels.map((s) => s.toLowerCase()).toSet().length != labels.length) {
      setState(
        () =>
            _error = 'Usa hasta ocho etiquetas distintas de 1 a 32 caracteres.',
      );
      return;
    }
    _attempt ??= (
      operationId: widget.preferences.source.newOperationId(),
      labels: List.unmodifiable(labels),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.preferences.saveLabels(
        widget.id,
        _attempt!.labels,
        _revision,
        _attempt!.operationId,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se ha confirmado el cambio. Reintenta el mismo envío o cierra y vuelve a abrir para consultar lo guardado.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text('Mis etiquetas · ${widget.name}'),
      content: SizedBox(
        width: 440,
        child: FutureBuilder<void>(
          future: _load,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return const Text(
                'No se pudieron leer las etiquetas. Cierra y vuelve a intentarlo.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Las etiquetas forman tus colecciones. Solo tú las ves; un ejercicio puede estar en varias. No cambian el catálogo ni las pautas del alumno.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _text,
                  enabled: !_busy && _attempt == null,
                  maxLength: 280,
                  decoration: const InputDecoration(
                    labelText: 'Etiquetas separadas por comas',
                    hintText: 'Oposición, técnica, iniciación',
                  ),
                ),
                if (_error != null) Text(_error!),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (_ready)
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _attempt == null ? 'Guardar etiquetas' : 'Reintentar mismo envío',
            ),
          ),
      ],
    ),
  );
}
