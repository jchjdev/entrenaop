import 'package:flutter/material.dart';

/// Acuse explícito, independiente de añadir una corrección al alumno.
class VideoReadButton extends StatefulWidget {
  const VideoReadButton({super.key, required this.markRead});
  final Future<void> Function() markRead;
  @override
  State<VideoReadButton> createState() => _VideoReadButtonState();
}

class _VideoReadButtonState extends State<VideoReadButton> {
  bool _busy = false, _done = false;
  String? _error;
  Future<void> _read() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.markRead();
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo confirmar. Reintenta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _busy || _done ? null : _read,
        icon: Icon(_done ? Icons.done_all : Icons.mark_email_read_outlined),
        label: Text(
          _done ? 'Vídeo marcado como visto' : 'Marcar vídeo como visto',
        ),
      ),
      if (_error != null) Text(_error!),
    ],
  );
}
