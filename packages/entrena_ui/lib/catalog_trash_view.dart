import 'package:flutter/material.dart';

import 'src/entrena_card.dart';
import 'src/entrena_dialog_actions.dart';
import 'src/professional_workspace.dart';
import 'src/workflow_exit_guard.dart';

/// Los adaptadores conservan los contratos de cada catálogo fuera de la vista.
class CatalogTrashItem {
  const CatalogTrashItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.trashedAt,
    this.revision,
    this.subtitle = '',
    this.blockedReason,
    this.restoreDescription,
    this.deleteDescription,
  });

  final String id, name, kind, subtitle;
  final DateTime trashedAt;
  final int? revision;
  final String? blockedReason, restoreDescription, deleteDescription;

  String get kindLabel => switch (kind) {
    'session' => 'sesión',
    'program' => 'programa',
    'exercise' => 'ejercicio',
    'work' => 'trabajo',
    _ => 'contenido',
  };

  String get _key => '$kind:$id';
}

Future<bool> showCatalogTrashConfirmation(
  BuildContext context, {
  required String name,
  required String kindLabel,
  String? description,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => EntrenaDialog(
        title: Text('¿Mover $kindLabel a la papelera?'),
        content: Text(
          description ??
              '«$name» dejará de aparecer en tu biblioteca. Podrás recuperarlo desde la papelera. Lo ya asignado y el historial se conservan.',
        ),
        actions: [
          EntrenaDialogActions(
            primaryLabel: 'Mover a papelera',
            onPrimary: () => Navigator.pop(context, true),
            secondary: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;

/// Papelera compartida. La autorización y el bloqueo de referencias pertenecen
/// al servidor; la vista conserva el recibo para reintentar respuestas perdidas.
class CatalogTrashView extends StatefulWidget {
  const CatalogTrashView({
    required this.title,
    required this.ownerKey,
    required this.load,
    required this.onRestore,
    required this.onDelete,
    required this.newOperationId,
    this.description,
    this.onBack,
    this.loadMore,
    this.pageSize = 50,
    this.showTitle = true,
    super.key,
  }) : assert(pageSize > 0);

  final String title;
  final Object ownerKey;
  final Future<List<CatalogTrashItem>> Function() load;
  final Future<List<CatalogTrashItem>> Function(CatalogTrashItem after)?
  loadMore;
  final Future<void> Function(
    CatalogTrashItem item,
    String operationId,
  ) onRestore,
      onDelete;
  final String Function() newOperationId;
  final String? description;
  final VoidCallback? onBack;
  final int pageSize;
  final bool showTitle;

  @override
  State<CatalogTrashView> createState() => _CatalogTrashViewState();
}

class _TrashAttempt {
  const _TrashAttempt(this.item, this.permanently, this.operationId);
  final CatalogTrashItem item;
  final bool permanently;
  final String operationId;
}

class _CatalogTrashViewState extends State<CatalogTrashView> {
  List<CatalogTrashItem> _items = [];
  bool _loading = true, _busy = false, _more = false, _confirming = false;
  int _epoch = 0;
  String? _error;
  _TrashAttempt? _attempt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CatalogTrashView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey) {
      _items = [];
      _attempt = null;
      _error = null;
      _busy = false;
      _confirming = false;
      _more = false;
      _load();
    }
  }

  bool _current(int epoch, Object owner) =>
      mounted && epoch == _epoch && owner == widget.ownerKey;

  Future<void> _load({bool more = false}) async {
    if (_busy || (more && (_loading || !_more || _items.isEmpty))) return;
    final epoch = ++_epoch;
    final owner = widget.ownerKey;
    final after = more ? _items.last : null;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = after == null
          ? await widget.load()
          : await widget.loadMore!(after);
      if (!_current(epoch, owner)) return;
      setState(() {
        if (more) {
          final existing = _items.map((item) => item._key).toSet();
          _items = [
            ..._items,
            ...page.where((item) => existing.add(item._key)),
          ];
        } else {
          _items = page;
        }
        _more = widget.loadMore != null && page.length >= widget.pageSize;
      });
    } catch (_) {
      if (_current(epoch, owner)) {
        setState(() {
          _error = 'No se pudo cargar la papelera. Vuelve a intentarlo.';
        });
      }
    } finally {
      if (_current(epoch, owner)) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(CatalogTrashItem item, bool permanently) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: Text(
            permanently
                ? '¿Borrar para siempre?'
                : '¿Recuperar ${item.kindLabel}?',
          ),
          content: Text(
            permanently
                ? item.deleteDescription ??
                      'Se eliminará «${item.name}» definitivamente. Esta acción no se puede deshacer. Si tiene usos que debamos conservar, el borrado se bloqueará.'
                : item.restoreDescription ??
                      '«${item.name}» volverá a tu biblioteca con sus versiones conservadas.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: permanently ? 'Cancelar' : 'Recuperar',
              onPrimary: () => Navigator.pop(context, !permanently),
              secondary: [
                if (permanently)
                  OutlinedButton(
                    style: EntrenaButtonStyles.destructive(context),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Borrar para siempre'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _act(
    CatalogTrashItem item, {
    bool permanently = false,
    bool retry = false,
  }) async {
    if (_busy || _loading || (!retry && _attempt != null)) return;
    if (permanently && item.blockedReason != null && !retry) return;
    final epoch = _epoch;
    final owner = widget.ownerKey;
    setState(() {
      _busy = true;
      _confirming = !retry;
      _error = null;
    });
    try {
      if (!retry) {
        final yes = await _confirm(item, permanently);
        if (!_current(epoch, owner) || !yes) return;
        _attempt = _TrashAttempt(item, permanently, widget.newOperationId());
        setState(() => _confirming = false);
      }
      final attempt = _attempt!;
      if (attempt.permanently) {
        await widget.onDelete(attempt.item, attempt.operationId);
      } else {
        await widget.onRestore(attempt.item, attempt.operationId);
      }
      if (!mounted || !_current(epoch, owner)) return;
      setState(() {
        _attempt = null;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permanently
                ? 'Borrado definitivo completado.'
                : 'Contenido recuperado. Puedes revisarlo en la biblioteca.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (_current(epoch, owner)) {
        setState(() {
          // Un rechazo de negocio confirma que no hubo escritura. Si se perdió
          // la respuesta, el mismo recibo permite consultar/repetir la operación.
          if (error is FormatException) _attempt = null;
          _error = error is FormatException ? error.message : 'No se pudo confirmar la operación. Reintenta para comprobar su resultado.';
        });
      }
    } finally {
      if (_current(epoch, owner)) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    final disabled = _loading || _busy || attempt != null;
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _attempt != null,
      isBusy: () => _busy,
      title: '¿Salir con una operación sin confirmar?',
      message: 'Todavía no conocemos el resultado de la operación. Puedes reintentarla aquí. Si sales, comprueba el estado de la papelera al volver.',
      exitLabel: 'Salir y comprobar después',
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(context),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.showTitle) ...[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                widget.description ?? 'Recupera contenido o borra definitivamente lo que ya no uses. Las referencias y el historial están protegidos. La papelera no se vacía automáticamente.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.onBack != null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver a la biblioteca'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _loading || _busy ? null : () => _load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar papelera'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (attempt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Operación pendiente de confirmar: «${attempt.item.name}».',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _loading || _busy
                        ? null
                        : () => _act(
                            attempt.item,
                            permanently: attempt.permanently,
                            retry: true,
                          ),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      attempt.permanently
                          ? 'Reintentar borrado'
                          : 'Reintentar recuperación',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_loading || (_busy && !_confirming))
                const LinearProgressIndicator(),
              if (!_loading && _items.isEmpty && _error == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('La papelera está vacía.'),
                ),
              for (final item in _items) ...[
                const SizedBox(height: 12),
                EntrenaCard(
                  key: ValueKey(item._key),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (item.subtitle.isNotEmpty) item.subtitle,
                          'En papelera desde ${_date(item.trashedAt)}',
                        ].join(' · '),
                      ),
                      if (item.blockedReason != null) ...[
                        const SizedBox(height: 8),
                        Text(item.blockedReason!),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: disabled ? null : () => _act(item),
                            icon: const Icon(Icons.restore_from_trash_outlined),
                            label: Text('Recuperar ${item.kindLabel}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: disabled || item.blockedReason != null
                                ? null
                                : () => _act(item, permanently: true),
                            style: EntrenaButtonStyles.destructive(context),
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Borrar definitivamente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_more) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _loading || _busy
                        ? null
                        : () => _load(more: true),
                    child: const Text('Cargar más'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
