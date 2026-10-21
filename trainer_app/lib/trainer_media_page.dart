import 'package:flutter/material.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';

import 'trainer_media_repository.dart';

String trainerMediaBytes(num bytes) => bytes >= 1024 * 1024 * 1024
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MiB';

class TrainerMediaPage extends StatefulWidget {
  const TrainerMediaPage({super.key, required this.repository, this.onSelect});
  final TrainerMediaRepository repository;
  final ValueChanged<String>? onSelect;
  @override
  State<TrainerMediaPage> createState() => _TrainerMediaPageState();
}

class _TrainerMediaPageState extends State<TrainerMediaPage> {
  List<TrainerMediaRow> _usage = [], _rows = [];
  bool _busy = true, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final usage = await widget.repository.usage();
      final rows = await widget.repository.list(
        before: more ? _rows.last : null,
      );
      if (mounted) {
        setState(() {
          _usage = usage;
          _rows = more ? [..._rows, ...rows] : rows;
          _more = rows.length == 50;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Medios privados'),
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
        const Text(
          'Tus demostraciones y el presupuesto de técnica de tus alumnos se cuentan por separado. Las reservas abandonadas también cuentan; no se borran vídeos históricos.',
        ),
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
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _upload(),
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Subir demostración'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
        if (!_busy && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no tienes vídeos gestionados. Puedes seguir pegando enlaces externos en el creador.',
            ),
          ),
        for (final row in _rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vídeo del ${(row['created_at'] as String).split('T').first}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${row['status']} · ${trainerMediaBytes(row['reserved_bytes'] as num)} reservados${row['duration_seconds'] == null ? '' : ' · ${row['duration_seconds']} s'}',
                  ),
                  if (row['status'] == 'ready') ...[
                    ExerciseVideoPreview(
                      url: row['playback_url'] as String,
                      source: widget.repository.source(),
                    ),
                    if (widget.onSelect != null)
                      TextButton(
                        onPressed: () =>
                            widget.onSelect!(row['playback_url'] as String),
                        child: const Text('Usar este vídeo'),
                      ),
                  ] else if (row['status'] == 'uploading' ||
                      row['status'] == 'processing')
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _check(row),
                          child: const Text('Comprobar estado'),
                        ),
                        if (row['status'] == 'uploading')
                          TextButton(
                            onPressed: _busy ? null : () => _upload(row),
                            child: const Text(
                              'Recuperar y continuar con el archivo original',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
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
