import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'exercise_video_source.dart';

/// Reproducción de un recurso autorizado, bajo demanda y sin controles de autoría.
class ExerciseVideoPreview extends StatefulWidget {
  const ExerciseVideoPreview({
    super.key,
    required this.url,
    required this.source,
    this.onPositionSelected,
  });
  final String url;
  final ExerciseVideoSource source;
  final ValueChanged<double>? onPositionSelected;
  @override
  State<ExerciseVideoPreview> createState() => _ExerciseVideoPreviewState();
}

class _ExerciseVideoPreviewState extends State<ExerciseVideoPreview> {
  VideoPlayerController? _controller;
  bool _busy = false;
  String? _error;
  int _request = 0;

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    VideoPlayerController? candidate;
    try {
      final signed = await widget.source.playback(widget.url);
      if (!mounted || request != _request) return;
      candidate = VideoPlayerController.networkUrl(signed);
      await candidate.initialize();
      if (!mounted || request != _request) {
        await candidate.dispose();
        return;
      }
      await _controller?.dispose();
      _controller = candidate;
      _controller!.addListener(_changed);
      setState(() => _busy = false);
    } catch (_) {
      await candidate?.dispose();
      if (mounted && request == _request) {
        setState(() {
          _busy = false;
          _error = 'No se pudo reproducir. Puedes reintentar.';
        });
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _request++;
      _controller?.removeListener(_changed);
      _controller?.dispose();
      _controller = null;
      _busy = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _request++;
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Reproducir vídeo'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
        ],
      );
    }
    final duration = controller.value.duration.inMilliseconds;
    final position = controller.value.position.inMilliseconds.clamp(
      0,
      duration,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Align(
            heightFactor: 1,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Slider(
          value: position.toDouble(),
          max: duration > 0 ? duration.toDouble() : 1,
          onChanged: duration > 0
              ? (value) =>
                    controller.seekTo(Duration(milliseconds: value.round()))
              : null,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: controller.value.isPlaying ? 'Pausar' : 'Reproducir',
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  if (position >= duration) {
                    await controller.seekTo(Duration.zero);
                  }
                  await controller.play();
                }
              },
            ),
            Text(
              '${(position / 1000).toStringAsFixed(1)} / ${(duration / 1000).toStringAsFixed(1)} s',
            ),
            if (widget.onPositionSelected != null)
              TextButton.icon(
                onPressed: () async {
                  await controller.pause();
                  if (mounted) widget.onPositionSelected!(position / 1000);
                },
                icon: const Icon(Icons.comment_outlined),
                label: const Text('Comentar este instante'),
              ),
          ],
        ),
      ],
    );
  }
}
