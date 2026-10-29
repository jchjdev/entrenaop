import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_catalog_trash_repository.dart';
import 'trainer_workout_repository.dart';

class TrainerCatalogTrashPage extends StatelessWidget {
  const TrainerCatalogTrashPage({
    super.key,
    required this.repository,
    required this.kind,
  });
  final TrainerCatalogTrashRepository repository;
  final TrainerCatalogKind kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Papelera de la biblioteca')),
      body: CatalogTrashView(
        key: ValueKey((repository.ownerKey, kind)),
        ownerKey: repository.ownerKey,
        title: 'Papelera · ${kind.label}',
        description: 'Aquí está el contenido que has retirado de tu biblioteca, junto con sus versiones. Las pautas ya asignadas y el historial se conservan. Los vínculos protegidos impiden el borrado definitivo.',
        newOperationId: trainerOperationId,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(kind.libraryPath),
        load: () async {
          final rows = await repository.list(kind);
          return rows.map(_item).toList();
        },
        loadMore: (after) async => (await repository.list(
          kind,
          before: _entry(after),
        )).map(_item).toList(),
        onRestore: (item, operation) =>
            repository.restore(operation, _entry(item)),
        onDelete: (item, operation) =>
            repository.purge(operation, _entry(item)),
      ),
    );
  }

  CatalogTrashItem _item(TrainerCatalogTrashEntry row) => CatalogTrashItem(
    id: row.id,
    name: row.name,
    kind: row.kind.name,
    trashedAt: row.trashedAt,
    revision: row.revision,
    blockedReason: row.blockedReason,
    deleteDescription:
        'Se eliminará «${row.name}» con todas sus versiones. No se podrá recuperar. '
        'El borrado se bloqueará si tiene usos que debamos conservar. '
        '${switch (row.kind) {
          TrainerCatalogKind.exercise => 'Las imágenes y vídeos asociados se conservan y siguen contando en sus límites.',
          TrainerCatalogKind.session => 'Sus ejercicios, imágenes y vídeos se conservan.',
          TrainerCatalogKind.program => 'Sus sesiones y ejercicios se conservan en sus bibliotecas.',
        }}',
  );

  TrainerCatalogTrashEntry _entry(CatalogTrashItem item) {
    if (item.kind != kind.name) {
      throw const FormatException('La entrada no corresponde a este catálogo.');
    }
    return TrainerCatalogTrashEntry(
      id: item.id,
      name: item.name,
      kind: kind,
      trashedAt: item.trashedAt,
      revision: item.revision,
      blockedReason: item.blockedReason,
    );
  }
}

/// La petición incierta mantiene su UUID y no cambia de contenido al reintentar.
class TrainerCatalogTrashAction extends StatefulWidget {
  const TrainerCatalogTrashAction({
    super.key,
    required this.repository,
    required this.kind,
    required this.id,
    required this.name,
    required this.onTrashed,
    this.enabled = true,
    this.onPendingChanged,
  });
  final TrainerCatalogTrashRepository repository;
  final TrainerCatalogKind kind;
  final String id, name;
  final bool enabled;
  final ValueChanged<bool>? onPendingChanged;
  final Future<void> Function() onTrashed;

  @override
  State<TrainerCatalogTrashAction> createState() =>
      _TrainerCatalogTrashActionState();
}

class _TrainerCatalogTrashActionState extends State<TrainerCatalogTrashAction> {
  String? _operationId, _error;
  bool _busy = false, _confirming = false;

  bool _sameTarget(TrainerCatalogTrashAction original) =>
      widget.repository == original.repository &&
      widget.kind == original.kind &&
      widget.id == original.id;

  @override
  void didUpdateWidget(covariant TrainerCatalogTrashAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTarget(oldWidget)) {
      _operationId = null;
      _error = null;
      _busy = false;
      _confirming = false;
    }
  }

  Future<void> _trash() async {
    if (_busy || _confirming || !widget.enabled) return;
    final target = widget;
    if (_operationId == null) {
      setState(() => _confirming = true);
      bool confirmed;
      try {
        confirmed = await showCatalogTrashConfirmation(
          context,
          name: target.name,
          kindLabel: target.kind.label,
          description:
              '«${target.name}» y todas sus versiones dejarán de estar disponibles para nuevas creaciones. Las asignaciones y el historial se conservan. Puedes restaurarlo desde Papelera.',
        );
      } finally {
        if (mounted && _sameTarget(target)) setState(() => _confirming = false);
      }
      if (!mounted || !_sameTarget(target) || !confirmed || !widget.enabled) {
        return;
      }
    }
    final operation = _operationId ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    target.onPendingChanged?.call(true);
    try {
      await target.repository.trash(operation, target.kind, target.id);
      if (!mounted || !_sameTarget(target)) return;
      setState(() {
        _operationId = null;
        _busy = false;
      });
      target.onPendingChanged?.call(false);
    } catch (error) {
      if (mounted && _sameTarget(target)) {
        setState(() {
          _busy = false;
          if (error is FormatException) {
            _operationId = null;
            _error = error.message;
            target.onPendingChanged?.call(false);
          } else {
            _error =
                'No se ha confirmado el envío a papelera. Reintenta la misma petición. ${trainerError(error)}';
          }
        });
      }
      return;
    }
    try {
      await target.onTrashed();
    } catch (_) {
      if (mounted && _sameTarget(target)) {
        setState(
          () => _error = 'El contenido está en la papelera, pero no se pudo actualizar la biblioteca. Vuelve a cargarla.',
        );
      }
    } finally {
      if (mounted && _sameTarget(target)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => false,
    isBusy: () => _busy || _confirming || _operationId != null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _busy || _confirming || !widget.enabled ? null : _trash,
          icon: const Icon(Icons.delete_outline),
          label: Text(
            _operationId == null
                ? 'Mover a papelera'
                : 'Reintentar envío a papelera',
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
