import 'package:flutter/material.dart';

import 'entrena_ui.dart';

/// Contexto de una demostración propia; nunca contiene una URL privada.
class MediaCleanupVideoTarget {
  const MediaCleanupVideoTarget({
    required this.ownerKey,
    required this.id,
    required this.name,
  });
  final Object ownerKey;
  final String id, name;
}

typedef MediaCleanupReport = Map<String, dynamic>;

/// Mantenimiento compartido; cada portal aporta sus permisos y transporte.
class MediaCleanupView extends StatefulWidget {
  const MediaCleanupView({
    super.key,
    required this.ownerKey,
    required this.inspect,
    required this.sweep,
    required this.run,
    required this.newOperationId,
    this.deleteVideo,
    this.initialVideo,
    this.onBack,
    this.showAppBar = true,
  });
  final Object ownerKey;
  final Future<MediaCleanupReport> Function() inspect, run;
  final Future<MediaCleanupReport> Function(String operationId) sweep;
  final Future<MediaCleanupReport> Function(String operationId, String assetId)?
  deleteVideo;
  final String Function() newOperationId;
  final MediaCleanupVideoTarget? initialVideo;
  final VoidCallback? onBack;
  final bool showAppBar;

  @override
  State<MediaCleanupView> createState() => _MediaCleanupViewState();
}

class _MediaCleanupViewState extends State<MediaCleanupView> {
  MediaCleanupReport? _report;
  _CleanupAttempt? _attempt;
  bool _busy = false,
      _loading = true,
      _confirming = false,
      _openedVideo = false;
  bool _requestedVideo = false;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MediaCleanupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerKey != widget.ownerKey) {
      _generation++;
      _report = null;
      _attempt = null;
      _busy = _confirming = _openedVideo = false;
      _requestedVideo = false;
      _refresh();
    }
  }

  bool _current(int generation, Object owner) =>
      mounted && generation == _generation && owner == widget.ownerKey;

  Future<void> _refresh() async {
    final generation = ++_generation;
    final owner = widget.ownerKey;
    setState(() => _loading = true);
    try {
      final report = await widget.inspect();
      if (!_current(generation, owner)) return;
      setState(() {
        _report = report;
        _loading = false;
        _error = null;
      });
      final video = widget.initialVideo;
      if (!_openedVideo && video != null) {
        _openedVideo = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current(generation, owner)) _perform(video: video);
        });
      }
    } catch (_) {
      if (_current(generation, owner)) {
        setState(() {
          _loading = false;
          _error = 'No se pudo consultar la limpieza. Tus archivos y sus reservas se conservan.';
        });
      }
    }
  }

  Future<bool> _confirm(MediaCleanupVideoTarget? video) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => EntrenaDialog(
          title: Text(
            video == null
                ? '¿Limpiar archivos sin uso?'
                : '¿Eliminar esta demostración?',
          ),
          content: Text(
            video == null
                ? 'Se revisarán imágenes sin referencias de al menos 24 horas y reservas fallidas o abandonadas. Las versiones, papelera, pautas e historial protegen sus archivos. Los vídeos listos de tu biblioteca no se eliminan por estar sin enlazar. La cuota se libera solo tras confirmar el borrado real.'
                : 'Se solicitará eliminar definitivamente «${video.name}». Esta acción no se puede deshacer. Si algún ejercicio, versión, pauta o historial utiliza el vídeo, quedará protegido. Nunca elimina vídeos de técnica de alumnos. La reserva se libera solo cuando se confirma el borrado real.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Cancelar',
              onPrimary: () => Navigator.pop(context, false),
              secondary: [
                OutlinedButton(
                  style: EntrenaButtonStyles.destructive(context),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    video == null
                        ? 'Limpiar archivos sin uso'
                        : 'Eliminar demostración',
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _perform({
    MediaCleanupVideoTarget? video,
    bool retry = false,
    bool run = false,
  }) async {
    if (_busy ||
        _confirming ||
        _loading ||
        (!retry && _attempt != null) ||
        (retry && _attempt == null)) {
      return;
    }
    if (video != null &&
        (video.ownerKey != widget.ownerKey || widget.deleteVideo == null)) {
      setState(
        () => _error =
            'Esta solicitud pertenece a otra cuenta o ya no está disponible.',
      );
      return;
    }
    final generation = _generation;
    final owner = widget.ownerKey;
    try {
      if (!retry && !run) {
        setState(() => _confirming = true);
        final confirmed = await _confirm(video);
        if (!confirmed || !_current(generation, owner)) return;
        _attempt = _CleanupAttempt(widget.newOperationId(), video);
      }
      setState(() {
        _confirming = false;
        _busy = true;
        _error = null;
      });
      final attempt = _attempt;
      final report = run
          ? await widget.run()
          : attempt!.video == null
          ? await widget.sweep(attempt.operationId)
          : await widget.deleteVideo!(attempt.operationId, attempt.video!.id);
      if (!_current(generation, owner)) return;
      setState(() {
        _report = report;
        if (attempt?.video != null) _requestedVideo = true;
        _attempt = null;
      });
    } catch (error) {
      if (_current(generation, owner)) {
        setState(() {
          if (error is FormatException) _attempt = null;
          _error = error is FormatException ? error.message : 'No se pudo confirmar el resultado. Reintenta la misma operación; la cuota todavía no se considera liberada.';
        });
      }
    } finally {
      if (_current(generation, owner)) {
        setState(() => _busy = _confirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _report?['summary'] as Map?;
    final items = (_report?['items'] as List? ?? const []).cast<Map>();
    final disabled = _busy || _confirming || _loading;
    return WorkflowDraftGuard(
      isBusy: () => _busy || _confirming,
      hasUnsavedChanges: () => _attempt != null,
      title: '¿Salir con una limpieza sin confirmar?',
      message: 'Todavía no conocemos el resultado de la solicitud. Puedes reintentarla con seguridad aquí. Si sales, comprueba su estado al volver.',
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(title: const Text('Archivos y almacenamiento'))
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: ProfessionalWorkspaceScope.pageConstraints(
              context,
              maxWidth: 1100,
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!widget.showAppBar)
                  Text(
                    'Archivos y almacenamiento',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Solo se libera espacio y cuota cuando el proveedor confirma el borrado. Lo utilizado por versiones, papelera, sesiones, pautas e historial sigue protegido.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se revisan hasta 50 archivos por solicitud. Repite la limpieza para revisar el siguiente lote.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.onBack != null)
                      OutlinedButton.icon(
                        onPressed: disabled ? null : widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver'),
                      ),
                    OutlinedButton.icon(
                      onPressed: disabled ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar estado'),
                    ),
                    FilledButton.icon(
                      onPressed: disabled || _attempt != null
                          ? null
                          : () => _perform(),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Limpiar archivos sin uso'),
                    ),
                    OutlinedButton.icon(
                      onPressed: disabled || _attempt != null
                          ? null
                          : () => _perform(run: true),
                      icon: const Icon(Icons.sync),
                      label: const Text('Procesar pendientes'),
                    ),
                    if (!_requestedVideo &&
                        widget.initialVideo != null &&
                        widget.initialVideo!.ownerKey == widget.ownerKey)
                      OutlinedButton.icon(
                        onPressed: disabled || _attempt != null
                            ? null
                            : () => _perform(video: widget.initialVideo),
                        style: EntrenaButtonStyles.destructive(context),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar demostración'),
                      ),
                  ],
                ),
                if (_loading || _busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!),
                  ),
                if (_attempt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: disabled ? null : () => _perform(retry: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar la misma operación'),
                    ),
                  ),
                if (summary != null) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Chip(label: Text('${summary['deleted']} limpiados')),
                      Chip(label: Text('${summary['pending']} pendientes')),
                      Chip(label: Text('${summary['protected']} protegidos')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuota recuperada: ${summary['freed_images']} reservas de imagen · ${((summary['freed_bytes'] as num) / (1024 * 1024)).toStringAsFixed(1)} MiB de reserva de vídeo.',
                  ),
                ],
                if (items.isEmpty && !_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No hay solicitudes de limpieza registradas.'),
                  ),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: EntrenaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['kind'] == 'video' ? 'Vídeo' : 'Imagen'} · ${switch (item['state']) {
                              'deleted' => 'Limpiado',
                              'blocked' => 'Protegido',
                              _ => 'Pendiente de confirmar',
                            }}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (item['blocked_reason'] case final String reason)
                            Text(switch (reason) {
                              'exercise_reference' => 'Lo utiliza un ejercicio o una versión conservada.',
                              'technique_history' || 'execution_history' =>
                                'Forma parte del historial de entrenamiento.',
                              'open_draft' => 'Lo utiliza un borrador abierto. Revisa ese borrador antes de volver a limpiar.',
                              'program_history' =>
                                'Lo utiliza un programa conservado.',
                              'device_history' => 'Forma parte de un entrenamiento enviado a un dispositivo.',
                              _ => 'Se conserva porque no se ha podido confirmar que pueda eliminarse con seguridad.',
                            }),
                          if (item['state'] == 'retry')
                            const Text(
                              'Se volverá a intentar. Su reserva todavía cuenta.',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CleanupAttempt {
  const _CleanupAttempt(this.operationId, this.video);
  final String operationId;
  final MediaCleanupVideoTarget? video;
}
