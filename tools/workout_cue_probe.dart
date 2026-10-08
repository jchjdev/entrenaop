// Banco manual de sonido con el reproductor, los controles y el temporizador
// reales. No inicia sesión ni consulta Supabase. Ejecutar con:
// flutter run -d chrome -t tools/workout_cue_probe.dart --web-port=55557
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/workouts/data/services/asset_workout_cue_audio.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final player = AudioPlayer();
  final service = SharedPreferencesWorkoutCueService(
    preferences,
    audio: AssetWorkoutCueAudio(player: player),
  );
  runApp(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: _Probe(player: player, service: service),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.player, required this.service});
  final AudioPlayer player;
  final SharedPreferencesWorkoutCueService service;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _events = <String>[];
  late final StreamSubscription<PlayerState> _subscription;
  int _seconds = 40;

  @override
  void initState() {
    super.initState();
    _subscription = widget.player.onPlayerStateChanged.listen((state) {
      if (mounted && state == PlayerState.playing) {
        setState(
          () => _events.add('Reproducción iniciada: ${widget.player.source}'),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(widget.service.dispose());
    super.dispose();
  }

  void _cue(WorkoutCue cue) => unawaited(widget.service.signal(cue));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Prueba de avisos EntrenaOP'),
      actions: [WorkoutCueSettingsButton(cueService: widget.service)],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Temporizador y audio reales, sin cuenta ni Supabase.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            for (final seconds in [5, 20, 40])
              ChoiceChip(
                label: Text('$seconds segundos'),
                selected: _seconds == seconds,
                onSelected: (_) => setState(() {
                  _seconds = seconds;
                  _events.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        WorkoutSetCountdown(
          key: ValueKey(_seconds),
          targetSeconds: _seconds,
          onElapsedChanged: (_) {},
          onPreparationTick: () => _cue(WorkoutCue.preparationTick),
          onStarted: () => _cue(WorkoutCue.workStarted),
          onHalfway: () => _cue(WorkoutCue.halfway),
          onTenSecondsRemaining: () => _cue(WorkoutCue.tenSecondsRemaining),
          onEndingTick: (_) => _cue(WorkoutCue.workEndingTick),
          onFinished: () => _cue(WorkoutCue.workFinished),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => _cue(WorkoutCue.restFinished),
          child: const Text('Probar final de descanso'),
        ),
        const SizedBox(height: 20),
        const Text('Estados confirmados por el reproductor:'),
        for (final event in _events.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(event),
          ),
      ],
    ),
  );
}
