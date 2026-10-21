import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

import 'exercise_video_source.dart';
import 'exercise_video_frame_picker.dart';

class ExerciseVideoField extends StatefulWidget {
  const ExerciseVideoField({
    super.key,
    required this.controller,
    required this.repository,
    required this.onBusyChanged,
    this.pickVideo,
    this.onCoverReady,
    this.pickFrame,
    this.maxVideoBytes = 20 * 1024 * 1024,
    this.maxVideoDurationSeconds = 10,
    this.allowExternalLinks = true,
    this.onPickExisting,
  });
  final TextEditingController controller;
  final ExerciseVideoSource repository;
  final ValueChanged<bool> onBusyChanged;
  final Future<XFile?> Function()? pickVideo;
  final bool Function(ExerciseImageUpload image, bool replaceExisting)?
  onCoverReady;
  final Future<Uint8List?> Function(BuildContext context, Uri video)? pickFrame;

  /// Límites de presentación; el adaptador y el servidor vuelven a verificarlos.
  final int maxVideoBytes, maxVideoDurationSeconds;

  /// Cada consumidor decide si ofrece edición de enlaces externos o solo subida.
  final bool allowExternalLinks;

  /// El consumidor consulta su biblioteca autorizada; el campo no conoce roles.
  final Future<String?> Function(BuildContext context)? onPickExisting;

  @override
  State<ExerciseVideoField> createState() => _ExerciseVideoFieldState();
}

class _ExerciseVideoFieldState extends State<ExerciseVideoField> {
  bool _busy = false;
  String? _pending;
  String? _message;
  double? _progress;
  VideoPlayerController? _preview;

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  void _setBusy(bool value) {
    setState(() => _busy = value);
    widget.onBusyChanged(value || _pending != null);
  }

  Future<void> _pick() async {
    _setBusy(true);
    setState(() {
      _message = 'Preparando subida…';
      _progress = null;
    });
    try {
      final file =
          await (widget.pickVideo?.call() ??
              ImagePicker().pickVideo(source: ImageSource.gallery));
      if (!mounted) return;
      if (file == null) {
        setState(() => _message = null);
        return;
      }
      final size = await file.length();
      if (size <= 0 || size > widget.maxVideoBytes) {
        throw FormatException(
          'El archivo debe ocupar como máximo ${(widget.maxVideoBytes / (1024 * 1024)).ceil()} MB.',
        );
      }
      final upload = await widget.repository.create(size);
      if (!mounted) {
        return;
      }
      _pending = upload.id;
      await widget.repository.upload(
        upload,
        await file.readAsBytes(),
        file.mimeType ??
            (file.name.toLowerCase().endsWith('.mov')
                ? 'video/quicktime'
                : 'video/mp4'),
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _message = 'Subiendo vídeo…';
            });
          }
        },
      );
      if (!mounted) return;
      await _check();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FormatException ? error.message : 'No se pudo completar. El vídeo anterior se conserva. Puedes descartar esta subida e intentarlo de nuevo.',
        );
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _pickExisting() async {
    final pick = widget.onPickExisting;
    if (pick == null || _busy || _pending != null) return;
    _setBusy(true);
    try {
      final url = await pick(context);
      if (!mounted || url == null) return;
      final error = ExerciseDraftValidator.videoUrlError(url);
      if (error != null || url.trim().isEmpty) {
        throw FormatException(error ?? 'El vídeo seleccionado no es válido.');
      }
      await _preview?.dispose();
      if (!mounted) return;
      setState(() {
        _preview = null;
        widget.controller.text = url.trim();
        _message = 'Vídeo seleccionado. Guarda el ejercicio para aplicarlo.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is FormatException
              ? error.message
              : 'No se pudo elegir el vídeo. Se conserva el anterior.';
        });
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _check() async {
    final id = _pending;
    if (id == null) return;
    if (!_busy) _setBusy(true);
    try {
      final result = await widget.repository.status(id);
      if (!mounted) return;
      if (result.status == 'ready' && result.url != null) {
        await _preview?.dispose();
        if (!mounted) return;
        _preview = null;
        widget.controller.text = result.url!;
        _pending = null;
        setState(
          () =>
              _message = 'Vídeo preparado. Previsualiza y guarda el ejercicio.',
        );
        if (widget.onCoverReady != null) await _prepareCover(false);
      } else if (result.status == 'rejected' || result.status == 'failed') {
        _pending = null;
        setState(
          () => _message =
              'Vídeo rechazado: comprueba que dure como máximo ${widget.maxVideoDurationSeconds} segundos y que se haya podido preparar. Se conserva el anterior.',
        );
      } else {
        setState(
          () => _message = 'El vídeo se está preparando. Comprueba su estado en unos segundos.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'No se pudo comprobar. Puedes reintentar sin volver a subir el archivo.',
        );
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _showPreview() async {
    _setBusy(true);
    try {
      final uri = await widget.repository.playback(widget.controller.text);
      final controller = VideoPlayerController.networkUrl(uri);
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _preview?.dispose();
      setState(() => _preview = controller);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'No se pudo abrir la previsualización. Reintenta antes de publicar.',
        );
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _prepareCover(bool replaceExisting) async {
    final apply = widget.onCoverReady;
    if (apply == null) return;
    _setBusy(true);
    try {
      final bytes = await widget.repository.thumbnail(widget.controller.text);
      if (!mounted) return;
      final image = await optimizeExerciseImage(bytes);
      if (!mounted) return;
      final applied = apply(image, replaceExisting);
      setState(
        () => _message = applied
            ? 'Vídeo y portada preparados. Guarda el ejercicio para publicarlos.'
            : 'Vídeo preparado. Se conserva la foto que has elegido.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'El vídeo está preparado, pero no se pudo generar la portada. Puedes reintentar o elegir una foto.',
        );
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _chooseFrame() async {
    final apply = widget.onCoverReady;
    if (apply == null) return;
    final reference = widget.controller.text;
    _setBusy(true);
    try {
      await _preview?.pause();
      final uri = await widget.repository.playback(reference);
      if (!mounted || reference != widget.controller.text) return;
      final bytes = await (widget.pickFrame ?? pickExerciseVideoFrame)(
        context,
        uri,
      );
      if (bytes == null || !mounted || reference != widget.controller.text) {
        return;
      }
      final image = await optimizeExerciseImage(bytes);
      if (!mounted || reference != widget.controller.text) return;
      final applied = apply(image, true);
      setState(
        () => _message = applied
            ? 'Fotograma elegido. Guarda el ejercicio para publicar la portada.'
            : 'No se pudo aplicar el fotograma. Reintenta cuando termine la foto.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'No se pudo elegir el fotograma. La portada anterior se conserva.',
        );
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Vídeo del ejercicio',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        'Subida: clip de hasta ${widget.maxVideoDurationSeconds} segundos y ${(widget.maxVideoBytes / (1024 * 1024)).ceil()} MB.${widget.allowExternalLinks ? ' También puedes usar un enlace externo HTTPS.' : ''}',
      ),
      const SizedBox(height: 8),
      if (widget.allowExternalLinks)
        TextFormField(
          controller: widget.controller,
          enabled: !_busy && _pending == null,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Vídeo externo',
            hintText: 'https://…',
            helperText: 'Opcional. Puedes pegar un enlace o subir un archivo.',
            helperMaxLines: 3,
          ),
          validator: ExerciseDraftValidator.videoUrlError,
          onChanged: (_) {
            _preview?.dispose();
            setState(() => _preview = null);
          },
        ),
      if (widget.allowExternalLinks) const SizedBox(height: 8),
      if (widget.onCoverReady != null &&
          _pending == null &&
          Uri.tryParse(widget.controller.text)?.host.endsWith('.b-cdn.net') ==
              true)
        Wrap(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _prepareCover(true),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('Usar portada del vídeo'),
            ),
            if (kIsWeb || widget.pickFrame != null)
              TextButton.icon(
                onPressed: _busy ? null : _chooseFrame,
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Elegir fotograma'),
              ),
          ],
        ),
      OutlinedButton.icon(
        onPressed: _busy || _pending != null ? null : _pick,
        icon: const Icon(Icons.video_call_outlined),
        label: Text(
          widget.controller.text.isEmpty ? 'Subir vídeo' : 'Sustituir vídeo',
        ),
      ),
      if (widget.onPickExisting != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || _pending != null ? null : _pickExisting,
          icon: const Icon(Icons.video_library_outlined),
          label: const Text('Elegir vídeo de mi biblioteca'),
        ),
      ],
      if (_busy)
        LinearProgressIndicator(
          value: _progress != null && _progress! < 1 ? _progress : null,
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_message!),
        ),
      if (_pending != null)
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _busy ? null : _check,
              child: const Text('Comprobar vídeo'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _pending = null;
                        _message = 'Se conserva el vídeo anterior.';
                      });
                      widget.onBusyChanged(false);
                    },
              child: const Text('Descartar esta subida'),
            ),
          ],
        ),
      if (widget.controller.text.isNotEmpty && _pending == null)
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _busy ? null : _showPreview,
              child: const Text('Previsualizar vídeo'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      _preview?.dispose();
                      setState(() {
                        _preview = null;
                        widget.controller.clear();
                        _message = 'El vídeo se retirará al guardar.';
                      });
                    },
              child: const Text('Retirar vídeo'),
            ),
          ],
        ),
      if (_preview case final preview?) ...[
        AspectRatio(
          aspectRatio: preview.value.aspectRatio,
          child: VideoPlayer(preview),
        ),
        IconButton(
          onPressed: () async {
            if (preview.value.isPlaying) {
              await preview.pause();
            } else {
              await preview.play();
            }
            if (mounted) setState(() {});
          },
          icon: Icon(preview.value.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
      ],
    ],
  );
}
