import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_media_repository.dart';

Future<String?> showTrainerMediaPicker(
  BuildContext context,
  TrainerMediaRepository repository,
) => showDialog<String>(
  context: context,
  builder: (dialogContext) => Dialog.fullscreen(
    child: TrainerMediaPage(
      repository: repository,
      onSelect: (url) => Navigator.of(dialogContext).pop(url),
    ),
  ),
);

String trainerMediaBytes(num bytes) => bytes >= 1024 * 1024 * 1024
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MiB';

String trainerVideoStatusLabel(Object? status) => switch (status) {
  'ready' => 'Listo',
  'uploading' => 'Subida sin completar',
  'processing' => 'Preparando vídeo',
  'failed' => 'No se pudo preparar',
  'rejected' => 'No admitido',
  _ => 'Estado no disponible',
};

class TrainerMediaPage extends StatefulWidget {
  const TrainerMediaPage({
    super.key,
    required this.repository,
    this.onSelect,
    this.onCreateExercise,
    this.onOpenTechnique,
  });
  final TrainerMediaRepository repository;
  final ValueChanged<String>? onSelect;
  final Future<void> Function(String videoUrl)? onCreateExercise;
  final VoidCallback? onOpenTechnique;
  @override
  State<TrainerMediaPage> createState() => _TrainerMediaPageState();
}

class _TrainerMediaPageState extends State<TrainerMediaPage> {
  List<TrainerMediaRow> _usage = [], _rows = [];
  bool _busy = true, _more = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrainerMediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _usage = [];
      _rows = [];
      _more = false;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final usage = widget.onSelect == null
          ? await widget.repository.usage()
          : <TrainerMediaRow>[];
      final rows = await widget.repository.list(
        before: more ? _rows.last : null,
      );
      if (mounted && request == _request) {
        setState(() {
          _usage = usage;
          _rows = more ? [..._rows, ...rows] : rows;
          _more = rows.length == 50;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
          _error = 'No se pudieron consultar los medios. Reintenta.';
        });
      }
    }
  }

  Future<void> _upload([TrainerMediaRow? resume]) async {
    final controller = TextEditingController();
    final source = widget.repository.source(resume: resume);
    final limits =
        resume ??
        _usage.firstWhere(
          (u) => u['scope'] == 'trainer_exercise',
          orElse: () => {
            'source_limit': 100 * 1024 * 1024,
            'duration_limit': 180,
          },
        );
    var busy = false;
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: Text(
                resume == null
                    ? 'Subir demostración privada'
                    : 'Continuar reserva',
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Cada reserva ocupa hasta 100 MiB del presupuesto aunque el archivo sea menor. No se publica en el catálogo oficial.',
                      ),
                      if (resume != null)
                        Text(
                          'Elige el archivo original de ${trainerMediaBytes(resume['source_bytes'] as num)}. La reserva se recuperará sin crear otro vídeo.',
                        ),
                      const SizedBox(height: 12),
                      if (controller.text.isNotEmpty && !busy)
                        const Text(
                          'Vídeo preparado. Ya está disponible en tus medios privados.',
                        )
                      else
                        ExerciseVideoField(
                          controller: controller,
                          repository: source,
                          maxVideoBytes: limits['source_limit'] as int,
                          maxVideoDurationSeconds:
                              limits['duration_limit'] as int,
                          allowExternalLinks: false,
                          onBusyChanged: (value) => update(() => busy = value),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      controller.dispose();
    }
    if (mounted) await _load();
  }

  Future<void> _check(TrainerMediaRow row) async {
    setState(() => _busy = true);
    try {
      await widget.repository.source().status(row['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo comprobar. La reserva se conserva.';
        });
      }
    }
  }

  Future<void> _createExercise(String url) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCreateExercise!(url);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir el creador. El vídeo se conserva en tu biblioteca.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _readyUrl(TrainerMediaRow row) {
    final url = row['playback_url'];
    return row['status'] == 'ready' &&
            url is String &&
            url.trim().isNotEmpty &&
            ExerciseDraftValidator.videoUrlError(url) == null
        ? url.trim()
        : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.onSelect == null ? 'Vídeos' : 'Elegir vídeo de mi biblioteca',
      ),
      leading: widget.onSelect == null
          ? null
          : IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Cancelar selección',
              icon: const Icon(Icons.close),
            ),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.onSelect == null
              ? 'Subir un vídeo lo guarda en tu biblioteca. Para que lo vea un alumno, enlázalo a un ejercicio y utiliza ese ejercicio en una sesión asignada.'
              : 'Elige una demostración preparada. Se añadirá al ejercicio cuando lo guardes.',
        ),
        const SizedBox(height: 12),
        if (widget.onSelect == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vídeos de tus alumnos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se guardan en la sesión que el alumno comparte contigo. Elige un alumno y consulta sus sesiones con ejecución.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Las reservas también incluyen subidas sin completar. Solo aparecen los clips compartidos contigo.',
                  ),
                  if (widget.onOpenTechnique != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : widget.onOpenTechnique,
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Consultar técnica de alumnos'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mis demostraciones',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Almacenamiento y límites'),
            subtitle: const Text(
              'Presupuesto separado para demostraciones y técnica',
            ),
            children: [
              for (final usage in _usage)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usage['scope'] == 'trainer_exercise'
                              ? 'Demostraciones propias'
                              : 'Técnica de alumnos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${usage['asset_used']} / ${usage['asset_limit']} reservas · ${trainerMediaBytes(usage['bytes_reserved'] as num)} / ${trainerMediaBytes(usage['byte_limit'] as num)} reservados',
                        ),
                        Text(
                          'Cada reserva consume ${trainerMediaBytes(usage['source_limit'] as num)}. El presupuesto puede agotarse antes del máximo de archivos.',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _upload(),
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Subir demostración'),
            ),
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
        if (!_busy &&
            _error == null &&
            (widget.onSelect == null
                ? _rows.isEmpty
                : !_rows.any((row) => _readyUrl(row) != null)))
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.onSelect == null
                  ? 'Todavía no tienes vídeos gestionados. Puedes seguir pegando enlaces externos en el creador.'
                  : 'No hay vídeos listos para elegir en esta página.',
            ),
          ),
        ProfessionalCatalogGrid(
          minCardWidth: 400,
          maxColumns: 3,
          children: [
            for (final row in _rows.where(
              (row) => widget.onSelect == null || _readyUrl(row) != null,
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vídeo del ${trainerDate(DateTime.parse(row['created_at'] as String))}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${trainerVideoStatusLabel(row['status'])} · ${trainerMediaBytes(row['reserved_bytes'] as num)} reservados${row['duration_seconds'] == null ? '' : ' · ${row['duration_seconds']} s'}',
                      ),
                      if (_readyUrl(row) case final url?) ...[
                        ExerciseVideoPreview(
                          url: url,
                          source: widget.repository.source(),
                        ),
                        if (widget.onSelect != null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => widget.onSelect!(url),
                            child: const Text('Usar este vídeo'),
                          ),
                        if (widget.onSelect == null &&
                            widget.onCreateExercise != null)
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _createExercise(url),
                            icon: const Icon(Icons.add),
                            label: const Text('Crear ejercicio con este vídeo'),
                          ),
                      ] else if (row['status'] == 'ready')
                        const Text(
                          'El vídeo no tiene un enlace de reproducción válido.',
                        )
                      else if (row['status'] == 'uploading' ||
                          row['status'] == 'processing')
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: _busy ? null : () => _check(row),
                              child: const Text('Comprobar estado'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => _upload(row),
                              child: Text(
                                row['status'] == 'processing'
                                    ? 'Revisar reserva y continuar'
                                    : 'Recuperar y continuar con el archivo original',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_more)
          OutlinedButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más vídeos'),
          ),
      ],
    ),
  );
}
