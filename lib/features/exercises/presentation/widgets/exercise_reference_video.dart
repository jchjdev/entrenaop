import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_it/get_it.dart';

import '../../data/services/exercise_video_playback.dart';

/// Carga bajo demanda: consultar un ejercicio no inicia descargas ni reproducción.
class ExerciseReferenceVideo extends StatefulWidget {
  const ExerciseReferenceVideo({
    super.key,
    required this.url,
    this.posterUrl,
    this.createController,
    this.openExternal,
  });
  final String url;
  final String? posterUrl;
  final VideoPlayerController Function(Uri)? createController;
  final Future<bool> Function(Uri)? openExternal;
  @override
  State<ExerciseReferenceVideo> createState() => _ExerciseReferenceVideoState();
}

class _ExerciseReferenceVideoState extends State<ExerciseReferenceVideo> {
  bool get _managed =>
      Uri.tryParse(widget.url)?.host.endsWith('.b-cdn.net') == true;
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  String? _linkError;
  String? _playbackError;
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
      _playbackError = null;
    });
    VideoPlayerController? candidate;
    try {
      final uri = Uri.tryParse(widget.url.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Vídeo HTTPS requerido.');
      }
      candidate = widget.createController != null
          ? widget.createController!(uri)
          : uri.host.endsWith('.b-cdn.net')
          ? await GetIt.instance<ExerciseVideoPlayback>().createController(uri)
          : VideoPlayerController.networkUrl(uri);
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
      return;
    }
    // La descarga y el arranque nacen del mismo toque, nunca al abrir la ficha.
    // Si el navegador exige otra interacción para el audio, queda el botón Play.
    await _togglePlayback();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final value = controller.value;
      if (value.isPlaying) {
        await controller.pause();
      } else {
        if (value.duration > Duration.zero &&
            value.position >= value.duration) {
          await controller.seekTo(Duration.zero);
        }
        if (!mounted || _controller != controller) return;
        await controller.play();
      }
      if (mounted && _controller == controller) {
        setState(() => _playbackError = null);
      }
    } catch (_) {
      if (mounted && _controller == controller) {
        setState(() {
          _playbackError = 'No se ha podido iniciar. Pulsa reproducir para intentarlo de nuevo.';
        });
      }
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
      _playbackError = null;
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
        if (controller == null)
          _poster(context)
        else
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio > 0
                              ? value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: value.isPlaying
                          ? 'Pausar vídeo'
                          : 'Reproducir vídeo',
                      onPressed: _togglePlayback,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_playbackError case final error?)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(error)),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _managed
                  ? 'No se ha podido cargar el vídeo. Comprueba la conexión y vuelve a intentarlo.'
                  : 'No se ha podido reproducir. El enlace debe apuntar a un archivo de vídeo compatible.',
            ),
          ),
        const SizedBox(height: 8),
        if (Uri.tryParse(widget.url.trim()) case final uri?
            when !_managed && uri.scheme == 'https' && uri.host.isNotEmpty)
          TextButton.icon(
            onPressed: _openLink,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir enlace original'),
          ),
        if (_linkError case final error?) Text(error),
        if (!_managed)
          SelectableText(
            widget.url,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _poster(BuildContext context) {
    final label = _loading
        ? 'Cargando vídeo…'
        : _failed
        ? 'Reintentar vídeo'
        : 'Reproducir vídeo';
    final image = widget.posterUrl?.trim();
    final onTap = _loading ? null : _load;
    return Semantics(
      button: true,
      label: label,
      enabled: !_loading,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null && image.isNotEmpty)
                    Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _failed
                                    ? Icons.refresh_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 4),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
