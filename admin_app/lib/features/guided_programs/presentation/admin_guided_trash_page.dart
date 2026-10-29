import 'package:entrena_ui/catalog_trash_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import '../../../core/admin_shell.dart';
import '../domain/admin_guided_trash.dart';

class AdminGuidedTrashPage extends StatefulWidget {
  const AdminGuidedTrashPage({
    super.key,
    required this.repository,
    this.sessions = false,
    this.ownerKey,
  });

  final AdminGuidedTrashRepository repository;
  final bool sessions;
  final Object? ownerKey;

  @override
  State<AdminGuidedTrashPage> createState() => _AdminGuidedTrashPageState();
}

class _AdminGuidedTrashPageState extends State<AdminGuidedTrashPage> {
  // Conserva identidad y revisión originales; no reconstruye el contrato
  // administrativo a partir de su representación visual incompleta.
  final _entries = Expando<GuidedTrashEntry>();

  String get _title =>
      widget.sessions ? 'Papelera de sesiones' : 'Papelera de programas';

  Future<List<CatalogTrashItem>> _load() async {
    final repository = widget.repository;
    final entries = await (widget.sessions
        ? repository.listSessions()
        : repository.list());
    return [for (final entry in entries) _item(entry)];
  }

  CatalogTrashItem _item(GuidedTrashEntry entry) {
    final item = CatalogTrashItem(
      id: entry.id,
      name: entry.name,
      kind: entry.isSession
          ? 'session'
          : entry.isWork
          ? 'work'
          : 'program',
      trashedAt: entry.trashedAt,
      revision: entry.revision,
      subtitle: entry.isSession
          ? 'Sesión · versión ${entry.versions}'
          : entry.isWork
          ? 'Trabajo incompleto'
          : '${entry.versions} ${entry.versions == 1 ? 'versión' : 'versiones'} · '
                '${entry.workCount} ${entry.workCount == 1 ? 'trabajo vinculado' : 'trabajos vinculados'}',
      restoreDescription: entry.isSession
          ? '«${entry.name}» volverá a Sesiones. Los borradores seguirán como borradores; '
                'las antiguas publicaciones quedarán retiradas para revisarlas antes de publicarlas de nuevo.'
          : entry.isWork
          ? '«${entry.name}» volverá a Continuar trabajando con su contenido guardado.'
          : 'Se recuperarán todas las versiones y trabajos vinculados de «${entry.name}». '
                'Los borradores seguirán como borradores. Lo que estaba publicado quedará retirado '
                'hasta que lo revises y publiques de nuevo.',
      deleteDescription:
          'Se eliminará «${entry.name}»${entry.isSession
              ? ' (esta versión)'
              : entry.isWork
              ? ''
              : ' con todas sus versiones y trabajos vinculados'}. '
          'No se podrá recuperar desde la papelera ni el historial. '
          '${entry.isSession
              ? 'Si tiene referencias o entrenamientos registrados, el servidor impedirá borrarla.'
              : entry.isWork
              ? 'Sus sesiones se conservarán.'
              : 'Sus sesiones se conservarán, también las compartidas con otros programas. '
                    'Si tiene seguimientos, el servidor impedirá borrarlo.'}',
    );
    _entries[item] = entry;
    return item;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(title: Text(_title)),
    body: CatalogTrashView(
      title: _title,
      ownerKey: (widget.ownerKey ?? widget.repository, widget.sessions),
      description: widget.sessions
          ? 'Recupera sesiones o elimina definitivamente las que no tengan referencias '
                'ni entrenamientos registrados. La papelera no se vacía automáticamente.'
          : 'Recupera programas y trabajos incompletos. El borrado definitivo conserva '
                'sus sesiones y se bloquea si hay seguimientos. La papelera no se vacía automáticamente.',
      load: _load,
      newOperationId: newGuidedWorkId,
      onRestore: (item, _) => widget.repository.restore(_entries[item]!),
      onDelete: (item, _) =>
          widget.repository.deletePermanently(_entries[item]!),
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(widget.sessions ? '/sessions' : '/guided-programs'),
    ),
  );
}
