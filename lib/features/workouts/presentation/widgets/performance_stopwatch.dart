import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workout_core/performance_time.dart';

/// Ayuda de captura manual. Medir tiempo no confirma que el intento fuera válido.
class PerformanceStopwatch extends StatefulWidget {
  const PerformanceStopwatch({required this.onElapsed, super.key});
  final ValueChanged<double> onElapsed;
  @override
  State<PerformanceStopwatch> createState() => _PerformanceStopwatchState();
}

class _PerformanceStopwatchState extends State<PerformanceStopwatch> {
  final _watch = Stopwatch();
  Timer? _ticker;
  double get _seconds => _watch.elapsedMilliseconds / 1000;
  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    super.dispose();
  }

  void _toggle() {
    if (_watch.isRunning) {
      _watch.stop();
      _ticker?.cancel();
      widget.onElapsed(_seconds);
    } else {
      _watch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        formatPerformanceTime(_seconds),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text(
        'Cronómetro manual. Detén el reloj antes de usar el resultado.',
      ),
      Wrap(
        spacing: 12,
        children: [
          FilledButton.tonal(
            onPressed: _toggle,
            child: Text(_watch.isRunning ? 'Detener' : 'Iniciar / continuar'),
          ),
          TextButton(
            onPressed: () {
              _watch.stop();
              _watch.reset();
              _ticker?.cancel();
              widget.onElapsed(0);
              setState(() {});
            },
            child: const Text('Reiniciar reloj'),
          ),
        ],
      ),
    ],
  );
}
