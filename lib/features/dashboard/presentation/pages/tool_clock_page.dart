import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workout_core/performance_time.dart';

enum _ClockMode {
  stopwatch('Cronómetro'),
  countdown('Temporizador'),
  intervals('Intervalos');

  const _ClockMode(this.label);
  final String label;
}

class ToolClockPage extends StatefulWidget {
  const ToolClockPage({required this.cueService, this.clock, super.key});

  final WorkoutCueService cueService;
  final Duration Function()? clock;

  @override
  State<ToolClockPage> createState() => _ToolClockPageState();
}

class _ToolClockPageState extends State<ToolClockPage> {
  static const _screenChannel = MethodChannel('es.entrenaop/clock_screen');
  static const _presets = {30: '30 s', 60: '1 min', 120: '2 min'};

  final _clock = Stopwatch();
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration? _sampleAt;
  bool _started = false;
  var _mode = _ClockMode.stopwatch;
  int? _preset = 60;
  String _custom = '';
  String _work = '20';
  String _rest = '10';
  String _rounds = '8';

  bool get _running => _sampleAt != null;
  Duration get _now => widget.clock?.call() ?? _clock.elapsed;
  int get _elapsedSeconds => _elapsed.inSeconds;
  int get _workSeconds => int.tryParse(_work) ?? 0;
  int get _restSeconds => int.tryParse(_rest) ?? 0;
  int get _roundCount => int.tryParse(_rounds) ?? 0;
  int get _cycle => _workSeconds + _restSeconds;
  int get _countdownSeconds => _preset ?? int.tryParse(_custom) ?? 0;

  bool get _valid => switch (_mode) {
    _ClockMode.stopwatch => true,
    _ClockMode.countdown => _countdownSeconds > 0,
    _ClockMode.intervals =>
      _workSeconds > 0 && _rest.isNotEmpty && _roundCount > 0,
  };

  int get _total => switch (_mode) {
    _ClockMode.stopwatch => 0,
    _ClockMode.countdown => _countdownSeconds,
    // El descanso separa rondas. La última termina al acabar el trabajo.
    _ClockMode.intervals => _cycle * _roundCount - _restSeconds,
  };

  bool get _finished =>
      _started && _mode != _ClockMode.stopwatch && _elapsedSeconds >= _total;
  int get _round => _cycle == 0 ? 1 : _elapsedSeconds ~/ _cycle + 1;
  bool get _resting => _cycle > 0 && _elapsedSeconds % _cycle >= _workSeconds;

  int get _displaySeconds => switch (_mode) {
    _ClockMode.stopwatch => _elapsedSeconds,
    _ClockMode.countdown => (_total - _elapsedSeconds).clamp(0, _total),
    _ClockMode.intervals when _finished || !_valid => 0,
    _ClockMode.intervals =>
      (_resting ? _cycle : _workSeconds) - _elapsedSeconds % _cycle,
  };

  @override
  void initState() {
    super.initState();
    _clock.start();
    _lifecycle = AppLifecycleListener(onHide: _pause);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _stop();
    _clock.stop();
    super.dispose();
  }

  Future<void> _keepScreenOn(bool enabled) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _screenChannel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      debugPrint('El control de pantalla del reloj no está disponible.');
    } on PlatformException catch (error) {
      debugPrint('No se ha podido ajustar la pantalla del reloj: $error');
    }
  }

  void _stop() {
    if (!_running) return;
    _sampleAt = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(_keepScreenOn(false));
  }

  void _advance() {
    final now = _now;
    // El pulso refresca la interfaz. El tiempo sale del reloj monotónico.
    _elapsed += now - _sampleAt!;
    _sampleAt = now;
  }

  void _pause() {
    if (!_running) return;
    setState(() {
      _advance();
      _stop();
    });
  }

  void _signal(WorkoutCue cue) => unawaited(widget.cueService.signal(cue));

  void _tick() {
    final previousRound = _round;
    final wasResting = _resting;
    setState(_advance);
    if (_finished) {
      _stop();
      _signal(WorkoutCue.workFinished);
    } else if (_mode == _ClockMode.intervals &&
        (previousRound != _round || wasResting != _resting)) {
      _signal(_resting ? WorkoutCue.workFinished : WorkoutCue.workStarted);
    }
  }

  void _start() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_finished) _reset();
      if (!_started && _mode == _ClockMode.intervals) {
        _signal(WorkoutCue.workStarted);
      }
      _started = true;
      _sampleAt = _now;
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick(),
      );
      unawaited(_keepScreenOn(true));
    });
  }

  void _reset() {
    _stop();
    _elapsed = Duration.zero;
    _started = false;
  }

  String get _status {
    if (_finished) return 'Terminado';
    if (_mode == _ClockMode.intervals && _started) {
      final phase = _resting ? 'Descanso' : 'Trabajo';
      final pause = _running ? '' : 'En pausa · ';
      return '$pause$phase · ronda $_round de $_roundCount';
    }
    if (_running) return 'En marcha';
    return _started ? 'En pausa' : 'Listo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = formatPerformanceTime(_displaySeconds).padLeft(5, '0');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reloj'),
        actions: [WorkoutCueSettingsButton(cueService: widget.cueService)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final mode in _ClockMode.values)
                        ChoiceChip(
                          label: Text(mode.label),
                          selected: _mode == mode,
                          onSelected: _running
                              ? null
                              : (selected) {
                                  if (!selected) return;
                                  setState(() {
                                    _reset();
                                    _mode = mode;
                                  });
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(_status, textAlign: TextAlign.center),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      time,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 96,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color:
                            _mode == _ClockMode.intervals &&
                                _started &&
                                !_finished
                            ? (_resting
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.primary)
                            : null,
                      ),
                    ),
                  ),
                  if (!_started) ...[
                    if (_mode == _ClockMode.countdown) _countdownOptions(),
                    if (_mode == _ClockMode.intervals) _intervalOptions(),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _running ? _pause : (_valid ? _start : null),
                    child: Text(
                      _running
                          ? 'Pausar'
                          : _finished
                          ? 'Repetir'
                          : _started
                          ? 'Reanudar'
                          : 'Iniciar',
                    ),
                  ),
                  if (_started)
                    TextButton(
                      onPressed: () => setState(_reset),
                      child: const Text('Reiniciar'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countdownOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final preset in _presets.entries)
            ChoiceChip(
              label: Text(preset.value),
              selected: _preset == preset.key,
              onSelected: (_) => setState(() => _preset = preset.key),
            ),
          ChoiceChip(
            label: const Text('Otro'),
            selected: _preset == null,
            onSelected: (_) => setState(() => _preset = null),
          ),
        ],
      ),
      if (_preset == null) ...[
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _custom,
          decoration: const InputDecoration(
            labelText: 'Tiempo en segundos',
            hintText: 'Ej. 90',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (value) => setState(() => _custom = value),
        ),
      ],
    ],
  );

  Widget _intervalOptions() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      _intervalField('Trabajo (s)', _work, (value) => _work = value),
      _intervalField('Descanso (s)', _rest, (value) => _rest = value),
      _intervalField('Rondas', _rounds, (value) => _rounds = value),
    ],
  );

  Widget _intervalField(
    String label,
    String value,
    ValueChanged<String> update,
  ) => SizedBox(
    width: 128,
    child: TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (value) => setState(() => update(value)),
    ),
  );
}
