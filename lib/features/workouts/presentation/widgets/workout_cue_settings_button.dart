import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/material.dart';

class WorkoutCueSettingsButton extends StatefulWidget {
  const WorkoutCueSettingsButton({required this.cueService, super.key});

  final WorkoutCueService cueService;

  @override
  State<WorkoutCueSettingsButton> createState() =>
      _WorkoutCueSettingsButtonState();
}

class _WorkoutCueSettingsButtonState extends State<WorkoutCueSettingsButton> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.cueService.prepare());
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Avisos del temporizador',
    icon: const Icon(Icons.notifications_active_outlined),
    onPressed: () async {
      final selected = await showDialog<WorkoutCuePreferences>(
        context: context,
        builder: (_) => _CueSettingsDialog(cueService: widget.cueService),
      );
      if (selected != null) await widget.cueService.savePreferences(selected);
    },
  );
}

class _CueSettingsDialog extends StatefulWidget {
  const _CueSettingsDialog({required this.cueService});

  final WorkoutCueService cueService;

  @override
  State<_CueSettingsDialog> createState() => _CueSettingsDialogState();
}

class _CueSettingsDialogState extends State<_CueSettingsDialog> {
  late bool _sound = widget.cueService.preferences.soundEnabled;
  late bool _haptics = widget.cueService.preferences.hapticsEnabled;
  bool _testing = false;
  String? _error;

  Future<void> _preview() async {
    setState(() {
      _testing = true;
      _error = null;
    });
    final success = await widget.cueService.previewSound();
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (!success) {
        _error = 'No se ha podido reproducir el sonido. Vuelve a probarlo.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Avisos del temporizador'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sound,
            title: const Text('Sonido'),
            subtitle: const Text(
              'Preparación, inicio, mitad, últimos 10 segundos y final. '
              'También durante el descanso.',
            ),
            onChanged: (value) => setState(() => _sound = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _haptics,
            title: const Text('Vibración'),
            subtitle: const Text(
              'Se aplicará cuando el dispositivo sea compatible.',
            ),
            onChanged: (value) => setState(() => _haptics = value),
          ),
          OutlinedButton.icon(
            onPressed: _sound && !_testing ? _preview : null,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(_testing ? 'Probando…' : 'Probar sonido'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Usa el volumen multimedia. Mantén la sesión en pantalla para '
            'recibir los avisos. Los intervalos cortos tienen menos avisos; '
            'los que coinciden suenan una sola vez.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          WorkoutCuePreferences(soundEnabled: _sound, hapticsEnabled: _haptics),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}
