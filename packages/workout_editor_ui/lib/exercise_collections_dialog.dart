import 'package:flutter/material.dart';

import 'exercise_collections.dart';
import 'exercise_preferences_controller.dart';

class ExerciseCollectionFilter extends StatelessWidget {
  const ExerciseCollectionFilter({
    super.key,
    required this.collections,
    required this.selected,
    required this.onChanged,
  });

  final Iterable<String> collections;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Filtrar por colecciones',
    onSelected: (name) => onChanged(name.isEmpty ? null : name),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Todas las colecciones')),
      for (final name in (collections.toSet().toList()..sort()))
        PopupMenuItem(value: name, child: Text(name)),
    ],
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Text(selected ?? 'Mis colecciones'),
    ),
  );
}

class ExerciseCollectionsButton extends StatelessWidget {
  const ExerciseCollectionsButton({
    super.key,
    required this.preferences,
    required this.exerciseId,
    required this.exerciseName,
    required this.catalogIds,
    this.enabled = true,
  });

  final ExercisePreferencesController preferences;
  final String exerciseId, exerciseName;
  final Iterable<String> catalogIds;
  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.folder_outlined),
    tooltip: 'Colecciones: $exerciseName',
    onPressed: enabled
        ? () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _ExerciseCollectionsDialog(
              preferences: preferences,
              exerciseId: exerciseId,
              exerciseName: exerciseName,
              catalogIds: catalogIds.toList(growable: false),
            ),
          )
        : null,
  );
}

class _ExerciseCollectionsDialog extends StatefulWidget {
  const _ExerciseCollectionsDialog({
    required this.preferences,
    required this.exerciseId,
    required this.exerciseName,
    required this.catalogIds,
  });

  final ExercisePreferencesController preferences;
  final String exerciseId, exerciseName;
  final List<String> catalogIds;

  @override
  State<_ExerciseCollectionsDialog> createState() =>
      _ExerciseCollectionsDialogState();
}

class _ExerciseCollectionsDialogState
    extends State<_ExerciseCollectionsDialog> {
  final _name = TextEditingController();
  final _selected = <String>{};
  final _available = <String>{};
  late Future<void> _load = _read();
  int _revision = 0;
  bool _creating = false, _busy = false;
  String? _nameError, _error;
  ({String operationId, List<String> collections})? _attempt;

  Future<void> _read() async {
    final preferences = widget.preferences;
    await preferences.refreshLabels();
    if (!mounted) return;
    _revision = preferences.labelsRevision(widget.exerciseId);
    _selected.addAll(preferences.labels(widget.exerciseId));
    _available
      ..addAll(widget.catalogIds.expand(preferences.labels))
      ..addAll(_selected);
  }

  void _toggle(String name, bool selected) => setState(() {
    if (!selected) {
      _selected.remove(name);
      _error = null;
    } else if (_selected.length >= 8) {
      _error = 'Puedes marcar hasta ocho colecciones.';
    } else if (_selected.any(
      (item) => item.toLowerCase() == name.toLowerCase(),
    )) {
      _error = 'Ya has marcado una colección con ese nombre.';
    } else {
      _selected.add(name);
      _error = null;
    }
  });

  void _addCollection() {
    final input = _name.text.trim();
    if (!isValidExerciseCollectionName(input)) {
      setState(
        () => _nameError = 'Escribe un nombre de 1 a 32 caracteres sin comas.',
      );
      return;
    }
    final name = _selected.firstWhere(
      (name) => name.toLowerCase() == input.toLowerCase(),
      orElse: () => resolveExerciseCollectionName(input, _available),
    );
    if (!_selected.contains(name)) {
      _toggle(name, true);
      if (!_selected.contains(name)) return;
    }
    setState(() {
      _available.add(name);
      _name.clear();
      _nameError = null;
      _creating = false;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = _attempt ??= (
        operationId: widget.preferences.source.newOperationId(),
        collections: List.unmodifiable(_selected),
      );
      await widget.preferences.saveLabels(
        widget.exerciseId,
        attempt.collections,
        _revision,
        attempt.operationId,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar el cambio. Reintenta el envío o vuelve a abrir para consultar las colecciones guardadas.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        final ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final editable = !_busy && _attempt == null;
        final names = _available.toList()..sort();
        return AlertDialog(
          scrollable: true,
          title: Text('Colecciones de ${widget.exerciseName}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(() {
                      _load = _read();
                    }),
                    child: const Text('Reintentar lectura de colecciones'),
                  )
                else if (!ready)
                  const LinearProgressIndicator()
                else ...[
                  const Text(
                    'Marca las colecciones privadas en las que quieres incluir este ejercicio.',
                  ),
                  const SizedBox(height: 8),
                  if (_creating) ...[
                    TextField(
                      autofocus: true,
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la colección',
                        errorText: _nameError,
                      ),
                      onSubmitted: (_) => _addCollection(),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _creating = false;
                            _name.clear();
                            _nameError = null;
                          }),
                          child: const Text('Cancelar nueva colección'),
                        ),
                        TextButton(
                          onPressed: _addCollection,
                          child: const Text('Crear colección'),
                        ),
                      ],
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: editable
                          ? () => setState(() => _creating = true)
                          : null,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Nueva colección'),
                    ),
                  for (final name in names)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(name),
                      value: _selected.contains(name),
                      onChanged: editable
                          ? (checked) => _toggle(name, checked == true)
                          : null,
                    ),
                ],
                if (_busy) const LinearProgressIndicator(),
                if (_error case final error?) Text(error),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            if (ready)
              FilledButton(
                onPressed: _busy || _creating ? null : _save,
                child: Text(
                  _attempt == null
                      ? 'Guardar colecciones'
                      : 'Reintentar mismo envío',
                ),
              ),
          ],
        );
      },
    ),
  );
}
