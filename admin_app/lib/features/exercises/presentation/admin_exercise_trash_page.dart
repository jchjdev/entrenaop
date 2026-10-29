import 'package:entrena_ui/catalog_trash_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import '../../../core/admin_shell.dart';
import '../data/admin_exercise_trash_repository.dart';

class AdminExerciseTrashPage extends StatelessWidget {
  const AdminExerciseTrashPage({
    super.key,
    required this.repository,
    this.ownerKey,
  });

  final AdminExerciseTrashRepository repository;
  final Object? ownerKey;

  static const title = 'Papelera de ejercicios';

  AdminExerciseTrashEntry _entry(CatalogTrashItem item) =>
      AdminExerciseTrashEntry(
        id: item.id,
        name: item.name,
        trashedAt: item.trashedAt,
        deleteBlockReason: item.blockedReason,
      );

  Future<List<CatalogTrashItem>> _load({CatalogTrashItem? before}) async => [
    for (final entry in await repository.listExerciseTrash(
      before: before == null ? null : _entry(before),
    ))
      CatalogTrashItem(
        id: entry.id,
        name: entry.name,
        kind: 'exercise',
        trashedAt: entry.trashedAt,
        blockedReason: entry.deleteBlockReason,
        restoreDescription:
            '«${entry.name}» volverá a Ejercicios como retirado. '
            'No aparecerá en el catálogo público hasta que lo revises y guardes de nuevo.',
        deleteDescription:
            'Se eliminará «${entry.name}» definitivamente. '
            'El borrado se bloqueará si está utilizado en sesiones, '
            'programas, asignaciones, ejecuciones u otros recursos protegidos. '
            'Las imágenes y los vídeos se conservan.',
      ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(title: const Text(title)),
    body: CatalogTrashView(
      title: title,
      showTitle: AdminShellScope.hidesAppBar(context),
      ownerKey: ownerKey ?? repository,
      newOperationId: newGuidedWorkId,
      description:
          'Los ejercicios se conservan en las sesiones y el historial que ya los utilizan. '
          'Recuperar no publica de nuevo: revisa y guarda el ejercicio para publicarlo. '
          'La papelera no se vacía automáticamente.',
      onBack: () => context.canPop() ? context.pop() : context.go('/exercises'),
      load: () => _load(),
      loadMore: (after) => _load(before: after),
      onRestore: (item, operationId) =>
          repository.restoreExercise(_entry(item), operationId: operationId),
      onDelete: (item, operationId) =>
          repository.purgeExercise(_entry(item), operationId: operationId),
    ),
  );
}
