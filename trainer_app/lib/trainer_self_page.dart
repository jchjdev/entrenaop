import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

/// La URL pública es estable; solo la respuesta confirmada abre la ficha propia.
class TrainerSelfPage extends StatefulWidget {
  const TrainerSelfPage({
    super.key,
    required this.ownerId,
    required this.ensure,
  });
  final String ownerId;
  final Future<void> Function() ensure;
  @override
  State<TrainerSelfPage> createState() => _TrainerSelfPageState();
}

class _TrainerSelfPageState extends State<TrainerSelfPage> {
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ensure();
      if (mounted) {
        context.go('/clients/${Uri.encodeComponent(widget.ownerId)}/workouts');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = trainerError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Para mí',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tu planificación personal, con tus sesiones y programas privados. No ocupa plaza de alumno.',
                ),
                const SizedBox(height: 16),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _open, child: const Text('Reintentar')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
