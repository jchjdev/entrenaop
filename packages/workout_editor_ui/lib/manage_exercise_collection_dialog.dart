import 'package:flutter/material.dart';

import 'exercise_collection_writes.dart';
import 'exercise_collections.dart';
import 'exercise_preferences_controller.dart';

Future<void> manageExerciseCollection(
  BuildContext context,
  ExercisePreferencesController preferences,
  String collection,
  ExerciseCollectionAction action,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ManageExerciseCollectionDialog(
    preferences: preferences,
    collection: collection,
    action: action,
  ),
);

class _ManageExerciseCollectionDialog extends StatefulWidget {
  const _ManageExerciseCollectionDialog({
    required this.preferences,
    required this.collection,
    required this.action,
  });

  final ExercisePreferencesController preferences;
  final String collection;
  final ExerciseCollectionAction action;

  @override
  State<_ManageExerciseCollectionDialog> createState() =>
      _ManageExerciseCollectionDialogState();
}

class _ManageExerciseCollectionDialogState
    extends State<_ManageExerciseCollectionDialog> {
  late final _name = TextEditingController(text: widget.collection);
  late Future<void> _load = widget.preferences.refreshLabels();
  ExerciseCollectionWrites? _pending;
  bool _saving = false;
  String? _error;

  bool get _rename => widget.action == ExerciseCollectionAction.rename;
  List<String> get _members => widget.preferences.organizedExerciseIds
      .where((id) => widget.preferences.labels(id).contains(widget.collection))
      .toList();

  ExerciseCollectionWrites? _prepare() {
    final preferences = widget.preferences;
    final name = _name.text.trim();
    if (_rename && !isValidExerciseCollectionName(name)) {
      setState(
        () => _error = 'Escribe un nombre de 1 a 32 caracteres sin comas.',
      );
      return null;
    }
    if (_rename &&
        preferences.organizedExerciseIds
            .expand(preferences.labels)
            .any(
              (label) =>
                  label != widget.collection &&
                  label.toLowerCase() == name.toLowerCase(),
            )) {
      setState(() => _error = 'Ya existe una colección con ese nombre.');
      return null;
    }
    return ExerciseCollectionWrites(preferences, [
      for (final id in _members)
        if (!_rename || name != widget.collection)
          (
            id: id,
            operationId: preferences.source.newOperationId(),
            revision: preferences.labelsRevision(id),
            labels: [
              for (final label in preferences.labels(id))
                if (label != widget.collection) label else if (_rename) name,
            ],
          ),
    ]);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final pending = _pending ??= _prepare();
      if (pending == null) return;
      await pending.save(isActive: () => mounted);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      final pending = _pending;
      setState(() {
        _error = pending == null
            ? 'No se pudo preparar el cambio. Vuelve a intentarlo.'
            : 'Cambios confirmados en ${pending.confirmed} de ${pending.writes.length} ejercicios. Puedes reintentar los pendientes o cerrar y volver a abrir para consultar lo guardado.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        final ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final count = _pending?.writes.length ?? (ready ? _members.length : 0);
        return AlertDialog(
          scrollable: true,
          title: Text(_rename ? 'Renombrar colección' : 'Eliminar colección'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!ready)
                  if (snapshot.connectionState == ConnectionState.done)
                    TextButton(
                      onPressed: () => setState(() {
                        _load = widget.preferences.refreshLabels();
                      }),
                      child: const Text('Reintentar lectura de colecciones'),
                    )
                  else
                    const LinearProgressIndicator()
                else if (count == 0)
                  const Text('La colección ya no tiene ejercicios asociados.')
                else ...[
                  Text(
                    '«${widget.collection}» · $count ${count == 1 ? 'ejercicio' : 'ejercicios'}',
                  ),
                  const SizedBox(height: 12),
                  if (_rename)
                    TextField(
                      autofocus: true,
                      controller: _name,
                      enabled: !_saving && _pending == null,
                      decoration: const InputDecoration(
                        labelText: 'Nuevo nombre',
                      ),
                      onSubmitted: (_) => _save(),
                    )
                  else
                    const Text(
                      'Los ejercicios seguirán en la biblioteca y conservarán sus demás colecciones.',
                    ),
                ],
                if (_saving) const LinearProgressIndicator(),
                if (_error case final error?) Text(error),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(_pending == null ? 'Cancelar' : 'Cerrar'),
            ),
            if (ready && count > 0)
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _pending != null
                      ? 'Reintentar pendientes'
                      : _rename
                      ? 'Guardar nombre'
                      : 'Eliminar colección',
                ),
              ),
          ],
        );
      },
    ),
  );
}
