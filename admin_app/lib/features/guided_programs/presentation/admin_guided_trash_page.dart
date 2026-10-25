import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/admin_shell.dart';
import '../domain/admin_guided_trash.dart';

class AdminGuidedTrashPage extends StatefulWidget {
  const AdminGuidedTrashPage({
    super.key,
    required this.repository,
    this.sessions = false,
  });
  final AdminGuidedTrashRepository repository;
  final bool sessions;
  @override
  State<AdminGuidedTrashPage> createState() => _AdminGuidedTrashPageState();
}

class _AdminGuidedTrashPageState extends State<AdminGuidedTrashPage> {
  List<GuidedTrashEntry>? _entries;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await (widget.sessions
          ? widget.repository.listSessions()
          : widget.repository.list());
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cargar la papelera. Reintenta para comprobar su estado.',
        );
      }
    }
  }

  String get _title =>
      widget.sessions ? 'Papelera de sesiones' : 'Papelera de programas';
  Future<void> _act(GuidedTrashEntry entry, {bool permanently = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final kind = entry.isSession
        ? 'sesión'
        : entry.isWork
        ? 'trabajo'
        : 'programa';
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => EntrenaDialog(
          title: Text(
            permanently ? '¿Borrar para siempre?' : '¿Recuperar $kind?',
          ),
          content: Text(
            permanently
                ? 'Se eliminará «${entry.name}»${entry.isSession
                          ? ' (esta versión)'
                          : entry.isWork
                          ? ''
                          : ' con todas sus versiones y trabajos vinculados'}. No se podrá recuperar desde la papelera ni el historial. '
                      '${entry.isSession
                          ? 'Si tiene referencias o entrenamientos registrados, el servidor impedirá borrarla.'
                          : entry.isWork
                          ? 'Sus sesiones se conservarán.'
                          : 'Sus sesiones se conservarán, también las compartidas con otros programas. Si tiene seguimientos, el servidor impedirá borrarlo.'}'
                : entry.isSession
                ? '«${entry.name}» volverá a Sesiones. Los borradores seguirán como borradores; las antiguas publicaciones quedarán retiradas para revisarlas antes de publicarlas de nuevo.'
                : entry.isWork
                ? '«${entry.name}» volverá a Continuar trabajando con su contenido guardado.'
                : 'Se recuperarán todas las versiones y trabajos vinculados de «${entry.name}». Los borradores seguirán como borradores. Lo que estaba publicado quedará retirado hasta que lo revises y publiques de nuevo.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: permanently ? 'Cancelar' : 'Recuperar',
              onPrimary: () => Navigator.of(ctx).pop(!permanently),
              secondary: [
                if (permanently)
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: EntrenaButtonStyles.destructive(ctx),
                    child: const Text(
                      'Borrar para siempre',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      if (permanently) {
        await widget.repository.deletePermanently(entry);
      } else {
        await widget.repository.restore(entry);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              permanently
                  ? 'Borrado definitivo completado. Las sesiones de otros recursos se conservan.'
                  : entry.isSession
                  ? 'Sesión recuperada. Puedes revisarla desde Sesiones.'
                  : 'Programa recuperado. Puedes continuar desde Programas guiados.',
            ),
          ),
        );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'No se pudo confirmar la operación. Actualiza la papelera antes de reintentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(title: Text(_title)),
    body: Center(
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1100,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              widget.sessions
                  ? 'Recupera sesiones o elimina definitivamente las que no tengan referencias ni entrenamientos registrados. La papelera no se vacía automáticamente.'
                  : 'Recupera programas y trabajos incompletos. El borrado definitivo conserva sus sesiones y se bloquea si hay seguimientos. La papelera no se vacía automáticamente.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => context.canPop()
                            ? context.pop()
                            : context.go(
                                widget.sessions
                                    ? '/sessions'
                                    : '/guided-programs',
                              ),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    widget.sessions
                        ? 'Volver a sesiones'
                        : 'Volver a programas',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar papelera'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!),
              ),
            if (_entries == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_entries?.isEmpty == true)
              const Text('La papelera está vacía.'),
            for (final entry in _entries ?? <GuidedTrashEntry>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.isSession
                            ? 'Sesión · versión ${entry.versions}'
                            : entry.isWork
                            ? 'Trabajo incompleto'
                            : '${entry.versions} ${entry.versions == 1 ? 'versión' : 'versiones'} · ${entry.workCount} ${entry.workCount == 1 ? 'trabajo vinculado' : 'trabajos vinculados'}',
                      ),
                      Text(
                        'En papelera desde ${entry.trashedAt.toLocal().toString().substring(0, 16)}',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _act(entry),
                            icon: const Icon(Icons.restore_from_trash_outlined),
                            label: Text(
                              entry.isSession
                                  ? 'Recuperar sesión'
                                  : 'Recuperar programa',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _act(entry, permanently: true),
                            style: EntrenaButtonStyles.destructive(context),
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Borrar definitivamente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
