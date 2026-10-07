import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carga bajo demanda: consultar un ejercicio no inicia descargas ni reproducción.
class ExerciseReferenceVideo extends StatefulWidget {
  const ExerciseReferenceVideo({
    super.key,
    required this.url,
    this.createController,
    this.openExternal,
  });
  final String url;
  final VideoPlayerController Function(Uri)? createController;
  final Future<bool> Function(Uri)? openExternal;
  @override
  State<ExerciseReferenceVideo> createState() => _ExerciseReferenceVideoState();
}

class _ExerciseReferenceVideoState extends State<ExerciseReferenceVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  String? _linkError;
  int _request = 0;

  Future<void> _openLink() async {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      final opened =
          await (widget.openExternal?.call(uri) ??
              launchUrl(uri, webOnlyWindowName: '_blank'));
      if (!opened) throw StateError('Enlace no abierto');
      if (mounted) setState(() => _linkError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _linkError = 'No se ha podido abrir el enlace. Puedes copiarlo.',
        );
      }
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    VideoPlayerController? candidate;
    try {
      final uri = Uri.tryParse(widget.url.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Vídeo HTTPS requerido.');
      }
      candidate =
          widget.createController?.call(uri) ??
          VideoPlayerController.networkUrl(uri);
      await candidate.initialize();
      if (!mounted || request != _request) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _controller = candidate;
        _loading = false;
      });
    } catch (_) {
      await candidate?.dispose();
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void didUpdateWidget(ExerciseReferenceVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _request++;
      _controller?.dispose();
      _controller = null;
      _loading = _failed = false;
      _linkError = null;
    }
  }

  @override
  void dispose() {
    _request++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vídeo de referencia',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (controller == null)
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline_rounded),
            label: Text(
              _loading
                  ? 'Cargando vídeo…'
                  : _failed
                  ? 'Reintentar vídeo'
                  : 'Ver vídeo',
            ),
          )
        else
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => Column(
              children: [
                AspectRatio(
                  aspectRatio: value.aspectRatio > 0
                      ? value.aspectRatio
                      : 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: VideoPlayer(controller),
                  ),
                ),
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                IconButton.filledTonal(
                  tooltip: value.isPlaying
                      ? 'Pausar vídeo'
                      : 'Reproducir vídeo',
                  onPressed: () async {
                    try {
                      if (value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                    } catch (_) {
                      if (mounted) setState(() => _failed = true);
                    }
                  },
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
        if (_failed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No se ha podido reproducir. El enlace debe apuntar a un archivo de vídeo compatible.',
            ),
          ),
        const SizedBox(height: 8),
        if (Uri.tryParse(widget.url.trim()) case final uri?
            when uri.scheme == 'https' && uri.host.isNotEmpty)
          TextButton.icon(
            onPressed: _openLink,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir enlace original'),
          ),
        if (_linkError case final error?) Text(error),
        SelectableText(
          widget.url,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
