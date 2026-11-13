import 'package:flutter/material.dart';

import 'exercise_collections.dart';
import 'exercise_preferences_controller.dart';

class ExerciseCollectionSelection {
  final ids = <String>{};
  bool active = false;

  void toggle(String id) {
    if (!ids.remove(id)) ids.add(id);
  }

  void clear() {
    ids.clear();
    active = false;
  }

  Widget checkbox(String id, String name, VoidCallback onToggle) => Checkbox(
    semanticLabel: 'Seleccionar $name',
    value: ids.contains(id),
    onChanged: (_) => onToggle(),
  );
}

class ExerciseCollectionActions extends StatelessWidget {
  const ExerciseCollectionActions({
    super.key,
    required this.selection,
    required this.onSelect,
    required this.onCancel,
    required this.onAdd,
  });

  final ExerciseCollectionSelection selection;
  final VoidCallback? onSelect;
  final VoidCallback onCancel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    if (!selection.active) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onSelect,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text(
            'Crear colección o añadir a una existente',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          selection.ids.isEmpty
              ? 'Marca los ejercicios que quieras añadir a la colección.'
              : 'Ejercicios seleccionados: ${selection.ids.length}',
        ),
        FilledButton.icon(
          onPressed: selection.ids.isEmpty ? null : onAdd,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Añadir a colección'),
        ),
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancelar selección'),
        ),
      ],
    );
  }
}

Future<bool?> addExercisesToCollection(
  BuildContext context,
  ExercisePreferencesController preferences, {
  required Map<String, String> selected,
  required Iterable<String> catalogIds,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AddToCollectionDialog(
    preferences: preferences,
    selected: selected,
    catalogIds: catalogIds.toList(growable: false),
  ),
);

class _AddToCollectionDialog extends StatefulWidget {
  const _AddToCollectionDialog({
    required this.preferences,
    required this.selected,
    required this.catalogIds,
  });

  final ExercisePreferencesController preferences;
  final Map<String, String> selected;
  final List<String> catalogIds;

  @override
  State<_AddToCollectionDialog> createState() => _AddToCollectionDialogState();
}

typedef _LabelWrite = ({
  String id,
  String operationId,
  int revision,
  List<String> labels,
});

class _AddToCollectionDialogState extends State<_AddToCollectionDialog> {
  final _name = TextEditingController();
  late Future<void> _load = widget.preferences.refreshLabels();
  List<_LabelWrite>? _writes;
  int _confirmed = 0;
  bool _busy = false;
  String? _error;

  List<String> get _collections =>
      widget.catalogIds.expand(widget.preferences.labels).toSet().toList()
        ..sort();

  List<_LabelWrite>? _prepare() {
    final input = _name.text.trim();
    if (!isValidExerciseCollectionName(input)) {
      setState(
        () => _error = 'Escribe un nombre de 1 a 32 caracteres sin comas.',
      );
      return null;
    }
    final key = input.toLowerCase();
    final name = resolveExerciseCollectionName(input, _collections);
    final writes = <_LabelWrite>[];
    for (final entry in widget.selected.entries) {
      final existing = widget.preferences.labels(entry.key);
      if (existing.contains(name)) continue;
      final equivalent = existing.indexWhere(
        (label) => label.toLowerCase() == key,
      );
      if (equivalent == -1 && existing.length >= 8) {
        setState(
          () => _error =
              '${entry.value} ya tiene ocho colecciones. Quita una de ellas o ajusta la selección.',
        );
        return null;
      }
      final labels = [...existing];
      if (equivalent == -1) {
        labels.add(name);
      } else {
        labels[equivalent] = name;
      }
      writes.add((
        id: entry.key,
        operationId: widget.preferences.source.newOperationId(),
        revision: widget.preferences.labelsRevision(entry.key),
        labels: labels,
      ));
    }
    return writes;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final writes = _writes ??= _prepare();
      if (writes == null) return;
      while (_confirmed < writes.length && mounted) {
        final write = writes[_confirmed];
        await widget.preferences.saveLabels(
          write.id,
          write.labels,
          write.revision,
          write.operationId,
        );
        _confirmed++;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _writes == null
              ? 'No se pudo preparar el cambio. Comprueba tu acceso y vuelve a intentarlo.'
              : 'Cambios confirmados: $_confirmed de ${_writes!.length}. Puedes reintentar los pendientes o cerrar y volver a abrir para consultar las colecciones guardadas.',
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
        final collections = _collections;
        return AlertDialog(
          scrollable: true,
          title: const Text('Añadir a colección'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ejercicios seleccionados: ${widget.selected.length}'),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(() {
                      _load = widget.preferences.refreshLabels();
                    }),
                    child: const Text('Reintentar lectura de colecciones'),
                  )
                else if (!ready)
                  const LinearProgressIndicator()
                else ...[
                  if (collections.isNotEmpty)
                    PopupMenuButton<String>(
                      enabled: !_busy && _writes == null,
                      onSelected: (name) => _name.text = name,
                      itemBuilder: (_) => [
                        for (final name in collections)
                          PopupMenuItem(value: name, child: Text(name)),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Elegir colección existente ▾'),
                      ),
                    ),
                  TextField(
                    controller: _name,
                    enabled: !_busy && _writes == null,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la colección',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ],
                if (_busy) const LinearProgressIndicator(),
                if (_error case final error?) Text(error),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: _busy || !ready ? null : _save,
              child: Text(_writes == null ? 'Añadir' : 'Reintentar pendientes'),
            ),
          ],
        );
      },
    ),
  );
}
