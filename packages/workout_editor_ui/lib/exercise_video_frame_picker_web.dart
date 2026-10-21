import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> pickExerciseVideoFrame(BuildContext context, Uri video) =>
    showDialog<Uint8List>(
      context: context,
      builder: (_) => _FramePicker(video: video),
    );

class _FramePicker extends StatefulWidget {
  const _FramePicker({required this.video});
  final Uri video;

  @override
  State<_FramePicker> createState() => _FramePickerState();
}

class _FramePickerState extends State<_FramePicker> {
  web.HTMLVideoElement? _video;
  final _listeners = <String, JSFunction>{};
  Timer? _timeout;
  double _duration = 0;
  double _position = 0;
  double _aspect = 16 / 9;
  bool _ready = false;
  bool _seeking = false;
  String? _error;

  void _attach(Object element) {
    final video = element as web.HTMLVideoElement;
    _video = video;
    video
      ..crossOrigin = 'anonymous'
      ..preload = 'auto'
      ..setAttribute('playsinline', '')
      ..setAttribute('aria-label', 'Fotograma del vídeo')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.pointerEvents = 'none';
    void listen(String event, void Function() action) {
      final callback = ((web.Event _) {
        if (mounted) action();
      }).toJS;
      _listeners[event] = callback;
      video.addEventListener(event, callback);
    }

    listen('loadeddata', () {
      _timeout?.cancel();
      if (!video.duration.isFinite ||
          video.duration <= 0 ||
          video.videoWidth == 0) {
        _fail();
        return;
      }
      setState(() {
        _duration = video.duration;
        _aspect = video.videoWidth / video.videoHeight;
        _ready = true;
      });
    });
    listen('seeked', () {
      _timeout?.cancel();
      setState(() {
        _position = video.currentTime;
        _seeking = false;
      });
    });
    listen('error', _fail);
    _timeout = Timer(const Duration(seconds: 25), _fail);
    video.src = widget.video.toString();
    video.load();
  }

  void _fail() {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() {
      _ready = false;
      _error = 'No se pudo obtener el fotograma. Cierra y vuelve a intentarlo; la portada anterior se conserva.';
    });
  }

  void _seek(double value) {
    final video = _video;
    if (video == null || !_ready) return;
    // El final exacto puede quedar fuera del último fotograma decodificable.
    final target = value
        .clamp(0.0, math.max(0.0, _duration - 0.001))
        .toDouble();
    if ((video.currentTime - target).abs() < 0.0001) return;
    setState(() {
      _position = target;
      _seeking = true;
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 15), _fail);
    video.currentTime = target;
  }

  void _capture() {
    final video = _video;
    if (!_ready || _seeking || video == null) return;
    try {
      final scale = math.min(
        1.0,
        math.min(1280 / video.videoWidth, 720 / video.videoHeight),
      );
      final canvas = web.HTMLCanvasElement()
        ..width = math.max(1, (video.videoWidth * scale).round())
        ..height = math.max(1, (video.videoHeight * scale).round());
      final painter = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      // Captura el vídeo pausado, no una captura de pantalla del editor.
      painter.drawImage(video, 0, 0, canvas.width, canvas.height);
      final data = canvas.toDataURL('image/jpeg', 0.9.toJS);
      final bytes = base64Decode(data.substring(data.indexOf(',') + 1));
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        throw const FormatException();
      }
      Navigator.of(context).pop(bytes);
    } catch (_) {
      _fail();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    final video = _video;
    if (video != null) {
      for (final entry in _listeners.entries) {
        video.removeEventListener(entry.key, entry.value);
      }
      video.pause();
      video.removeAttribute('src');
      video.load();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Elegir fotograma'),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mueve la barra hasta la postura que quieras usar como portada.',
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: _aspect,
              child: ColoredBox(
                color: Colors.black,
                child: HtmlElementView.fromTagName(
                  tagName: 'video',
                  onElementCreated: _attach,
                ),
              ),
            ),
            if (!_ready && _error == null) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_ready) ...[
              Text(
                '${_position.toStringAsFixed(2)} s / ${_duration.toStringAsFixed(2)} s',
              ),
              Slider(
                label: '${_position.toStringAsFixed(2)} s',
                semanticFormatterCallback: (value) =>
                    '${value.toStringAsFixed(2)} segundos',
                min: 0,
                max: _duration,
                value: _position.clamp(0.0, _duration),
                onChanged: _seek,
              ),
              if (_seeking) const Text('Buscando fotograma…'),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _ready && !_seeking ? _capture : null,
        child: const Text('Usar como portada'),
      ),
    ],
  );
}
