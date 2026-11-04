import 'dart:async';

import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

class _ToolClockPageState extends State<ToolClockPage>
    with SingleTickerProviderStateMixin {
  static const _screenChannel = MethodChannel('es.entrenaop/clock_screen');
  static const _presets = {30: '30 s', 60: '1 min', 120: '2 min'};

  final _clock = Stopwatch();
  final _laps = <Duration>[];
  late final AppLifecycleListener _lifecycle;
  Ticker? _stopwatchTicker;
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
    _stopwatchTicker?.dispose();
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
    _stopwatchTicker?.stop();
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
    final previousElapsed = _elapsed;
    final previousRound = _round;
    final wasResting = _resting;
    setState(_advance);
    if (_finished) {
      _stop();
      _signal(WorkoutCue.workFinished);
    } else if (_mode == _ClockMode.intervals &&
        (previousRound != _round || wasResting != _resting)) {
      _signal(_resting ? WorkoutCue.workFinished : WorkoutCue.workStarted);
    } else if (_mode == _ClockMode.countdown || !_resting) {
      final halfway = _mode == _ClockMode.countdown
          ? Duration(seconds: _total) ~/ 2
          : Duration(seconds: (_round - 1) * _cycle) +
                Duration(seconds: _workSeconds) ~/ 2;
      if (previousElapsed < halfway && _elapsed >= halfway) {
        _signal(WorkoutCue.halfway);
      }
    }
  }

  void _start() {
    if (_running || !_valid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      if (_finished) _reset();
      if (!_started && _mode == _ClockMode.intervals) {
        _signal(WorkoutCue.workStarted);
      }
      _started = true;
      _sampleAt = _now;
      if (_mode == _ClockMode.stopwatch) {
        (_stopwatchTicker ??= createTicker((_) => setState(_advance))).start();
      } else {
        _ticker = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => _tick(),
        );
      }
      unawaited(_keepScreenOn(true));
    });
  }

  void _reset() {
    _stop();
    _elapsed = Duration.zero;
    _laps.clear();
    _started = false;
  }

  void _lap() {
    if (!_running) return;
    setState(() {
      // La vuelta usa el instante de la pulsación, aunque aún no haya otro frame.
      _advance();
      _laps.add(_elapsed);
    });
  }

  String _formatStopwatch(Duration elapsed) {
    final time = formatPerformanceTime(elapsed.inSeconds).padLeft(5, '0');
    final milliseconds = (elapsed.inMilliseconds % 1000).toString().padLeft(
      3,
      '0',
    );
    return '$time.$milliseconds';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reloj'),
        actions: [WorkoutCueSettingsButton(cueService: widget.cueService)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 550 &&
                MediaQuery.orientationOf(context) == Orientation.landscape) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FittedBox(fit: BoxFit.scaleDown, child: _face()),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _modeSelector(),
                            ..._options(),
                            const SizedBox(height: 8),
                            _actions(compact: true),
                            if (_laps.isNotEmpty) _lapList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _modeSelector(),
                      const SizedBox(height: 20),
                      _face(),
                      ..._options(),
                      const SizedBox(height: 20),
                      _actions(compact: false),
                      if (_laps.isNotEmpty) _lapList(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _modeSelector() => Wrap(
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
  );

  Widget _face() {
    final theme = Theme.of(context);
    final time = _mode == _ClockMode.stopwatch
        ? _formatStopwatch(_elapsed)
        : formatPerformanceTime(_displaySeconds).padLeft(5, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_status, textAlign: TextAlign.center),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            time,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 96,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: _mode == _ClockMode.intervals && _started && !_finished
                  ? (_resting
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _options() => [
    if (!_started && _mode == _ClockMode.countdown) _countdownOptions(),
    if (!_started && _mode == _ClockMode.intervals) _intervalOptions(),
  ];

  Widget _actions({required bool compact}) {
    final startPause = FilledButton(
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
    );
    final secondary = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (compact) startPause,
        if (_mode == _ClockMode.stopwatch && _running)
          FilledButton.tonal(onPressed: _lap, child: const Text('Vuelta')),
        if (_started)
          TextButton(
            onPressed: () => setState(_reset),
            child: const Text('Reiniciar'),
          ),
      ],
    );
    return compact
        ? secondary
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [startPause, secondary],
          );
  }

  Widget _lapList() => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 128),
    child: ListView.builder(
      primary: false,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _laps.length,
      itemBuilder: (context, index) {
        final lap = _laps.length - 1 - index;
        final split = _laps[lap] - (lap == 0 ? Duration.zero : _laps[lap - 1]);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text('Vuelta ${lap + 1}'),
              Text(_formatStopwatch(split)),
            ],
          ),
        );
      },
    ),
  );

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
