import 'package:entrenaop/features/running_tools/domain/services/running_pace_calculator.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _CalculationMode { time, pace }

class RunningPaceCalculatorPage extends StatefulWidget {
  const RunningPaceCalculatorPage({super.key});

  @override
  State<RunningPaceCalculatorPage> createState() =>
      _RunningPaceCalculatorPageState();
}

class _RunningPaceCalculatorPageState extends State<RunningPaceCalculatorPage> {
  static const _calculator = RunningPaceCalculator();
  static const _seriesDistances = <double>[
    100,
    200,
    300,
    400,
    500,
    600,
    800,
    1000,
    1200,
    1500,
    1600,
    2000,
  ];
  static final _raceDistances = <double, String>{
    5000: '5 km',
    10000: '10 km',
    21097.5: 'Media maratón',
    42195: 'Maratón',
  };
  static const _seriesSplitOptions = [100, 200, 400, 500, 1000];
  static const _raceSplitOptions = [1000, 5000];

  final _paceController = TextEditingController(text: '03:40');
  final _distanceController = TextEditingController(text: '400');
  final _targetTimeController = TextEditingController();
  _CalculationMode _mode = _CalculationMode.time;
  bool _showRaces = false;
  bool _useKilometers = false;
  int? _selectedSplit;

  @override
  void dispose() {
    _paceController.dispose();
    _distanceController.dispose();
    _targetTimeController.dispose();
    super.dispose();
  }

  double? get _distance {
    final value = double.tryParse(
      _distanceController.text.replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite) return null;
    // La entrada admite décimas de metro, también al convertir desde kilómetros.
    return (value * (_useKilometers ? 1000 : 1) * 10).roundToDouble() / 10;
  }

  bool _validDistance(double? distance) =>
      distance != null &&
      distance >= 1 &&
      distance <= RunningPaceCalculator.maxDistanceMeters;

  Iterable<int> _splitOptions(double distance) =>
      (distance > 2000 ? _raceSplitOptions : _seriesSplitOptions).where(
        (split) => split < distance,
      );

  void _resetUnavailableSplit() {
    final distance = _distance;
    if (distance == null || !_splitOptions(distance).contains(_selectedSplit)) {
      _selectedSplit = null;
    }
  }

  void _setUnit(bool kilometers) {
    final distance = _distance;
    _useKilometers = kilometers;
    if (distance != null) {
      _distanceController.text = _number(distance / (kilometers ? 1000 : 1));
    }
  }

  RunningPaceCalculation? get _calculation {
    final distance = _distance;
    if (!_validDistance(distance)) return null;
    final split = _selectedSplit ?? _calculator.automaticSplitMeters(distance!);
    if (_mode == _CalculationMode.pace) {
      final target = parseDurationInput(_targetTimeController.text);
      if (target == null || target <= 0) return null;
      return _calculator.calculateFromTime(
        totalSeconds: target,
        distanceMeters: distance!,
        splitMeters: split,
      );
    }
    final pace = parseDurationInput(_paceController.text);
    if (pace == null || pace <= 0) return null;
    return _calculator.calculate(
      paceSecondsPerKilometer: pace,
      distanceMeters: distance!,
      splitMeters: split,
    );
  }

  void _selectDistance(double distance) {
    setState(() {
      _distanceController.text = _number(
        distance / (_useKilometers ? 1000 : 1),
      );
      _resetUnavailableSplit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final calculation = _calculation;
    final distance = _distance;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de ritmos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Del ritmo al cronómetro',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige la distancia y calcula tu tiempo final o el ritmo para llegar a tu objetivo, con todos los parciales.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const ValueKey('running-distance-input'),
                            controller: _distanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              TextInputFormatter.withFunction((
                                oldValue,
                                newValue,
                              ) {
                                final pattern = _useKilometers
                                    ? r'^\d{0,6}([,.]\d{0,4})?$'
                                    : r'^\d{0,6}([,.]\d{0,1})?$';
                                return RegExp(pattern).hasMatch(newValue.text)
                                    ? newValue
                                    : oldValue;
                              }),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Distancia',
                              suffixIcon: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: DropdownButton<bool>(
                                  key: const ValueKey('running-distance-unit'),
                                  value: _useKilometers,
                                  underline: const SizedBox.shrink(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: false,
                                      child: Text('m'),
                                    ),
                                    DropdownMenuItem(
                                      value: true,
                                      child: Text('km'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _setUnit(value));
                                    }
                                  },
                                ),
                              ),
                              helperText: 'Entre 1 m y 100 km',
                              errorText: !_validDistance(distance)
                                  ? 'Introduce una distancia válida'
                                  : null,
                              prefixIcon: const Icon(Icons.straighten_rounded),
                            ),
                            onChanged: (_) => setState(_resetUnavailableSplit),
                          ),
                          const SizedBox(height: 18),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Series'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Carreras'),
                              ),
                            ],
                            selected: {_showRaces},
                            onSelectionChanged: (selection) => setState(() {
                              _showRaces = selection.single;
                              _setUnit(_showRaces);
                            }),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            children:
                                (_showRaces
                                        ? _raceDistances
                                        : {
                                            for (final meters
                                                in _seriesDistances)
                                              meters: _formatDistance(meters),
                                          })
                                    .entries
                                    .map(
                                      (preset) => ChoiceChip(
                                        label: Text(preset.value),
                                        selected: distance == preset.key,
                                        onSelected: (_) =>
                                            _selectDistance(preset.key),
                                      ),
                                    )
                                    .toList(growable: false),
                          ),
                          const SizedBox(height: 22),
                          DropdownButtonFormField<_CalculationMode>(
                            key: const ValueKey('running-calculation-mode'),
                            initialValue: _mode,
                            isExpanded: true,
                            isDense: false,
                            itemHeight: null,
                            decoration: const InputDecoration(
                              labelText: 'Cálculo',
                              prefixIcon: Icon(Icons.calculate_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _CalculationMode.time,
                                child: Text('Calcular tiempo'),
                              ),
                              DropdownMenuItem(
                                value: _CalculationMode.pace,
                                child: Text('Calcular ritmo'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              FocusScope.of(context).unfocus();
                              setState(() => _mode = value);
                            },
                          ),
                          const SizedBox(height: 18),
                          if (_mode == _CalculationMode.time)
                            TextField(
                              key: const ValueKey('running-pace-input'),
                              controller: _paceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [DurationInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Ritmo objetivo (min:seg/km)',
                                hintText: '00:00',
                                helperText: 'Escribe, por ejemplo, 3:40',
                                prefixIcon: Icon(Icons.speed_rounded),
                              ),
                              onChanged: (_) => setState(() {}),
                            )
                          else
                            TextField(
                              key: const ValueKey('running-target-time-input'),
                              controller: _targetTimeController,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [DurationInputFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Tiempo objetivo',
                                hintText: '00:00',
                                helperText: 'Min:seg, por ejemplo 6:20. Para horas: 1:30:00',
                                helperMaxLines: 4,
                                errorText:
                                    _targetTimeController.text.isNotEmpty &&
                                        (parseDurationInput(
                                                  _targetTimeController.text,
                                                ) ??
                                                0) <=
                                            0
                                    ? 'Introduce un tiempo válido mayor que cero'
                                    : null,
                                prefixIcon: const Icon(Icons.timer_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          if (_validDistance(distance) && distance! > 100) ...[
                            const SizedBox(height: 22),
                            const Text(
                              'Parciales',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedSplit == null
                                  ? 'Automático · cada ${_formatDistance(_calculator.automaticSplitMeters(distance).toDouble())}'
                                  : 'Cada ${_formatDistance(_selectedSplit!.toDouble())}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: [
                                ChoiceChip(
                                  label: const Text('Auto'),
                                  selected: _selectedSplit == null,
                                  onSelected: (_) =>
                                      setState(() => _selectedSplit = null),
                                ),
                                ..._splitOptions(distance).map(
                                  (split) => ChoiceChip(
                                    label: Text(
                                      _formatDistance(split.toDouble()),
                                    ),
                                    selected: _selectedSplit == split,
                                    onSelected: (_) =>
                                        setState(() => _selectedSplit = split),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (calculation != null)
                    _ResultCard(
                      calculation: calculation,
                      showPace: _mode == _CalculationMode.pace,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _mode == _CalculationMode.time
                              ? 'Revisa el ritmo y la distancia para calcular el tiempo.'
                              : 'Introduce la distancia y el tiempo objetivo para calcular el ritmo.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.calculation, required this.showPace});

  final RunningPaceCalculation calculation;
  final bool showPace;

  @override
  Widget build(BuildContext context) {
    final hasIntermediateSplits = calculation.splits.length > 1;
    return Card(
      key: const ValueKey('running-pace-result'),
      color: const Color(0xFF21130E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              showPace ? 'Ritmo necesario' : 'Tiempo total',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                showPace
                    ? _paceLabel(calculation.paceSecondsPerKilometer)
                    : _clock(calculation.totalSeconds),
                key: ValueKey(
                  showPace ? 'running-required-pace' : 'running-total-time',
                ),
                style: const TextStyle(
                  color: Color(0xFFFF8A50),
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showPace
                  ? '${_formatDistance(calculation.distanceMeters)} en ${_clock(calculation.totalSeconds)}'
                  : '${_formatDistance(calculation.distanceMeters)} a ${_paceLabel(calculation.paceSecondsPerKilometer)}',
              style: const TextStyle(color: Colors.white60),
            ),
            if (showPace &&
                calculation.paceSecondsPerKilometer !=
                    calculation.paceSecondsPerKilometer.round()) ...[
              const SizedBox(height: 8),
              const Text(
                'Ritmo aproximado al segundo. Los parciales conservan tu tiempo objetivo.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
            if (hasIntermediateSplits) ...[
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth /
                          (MediaQuery.textScalerOf(context).scale(14) / 14) <
                      240;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!compact) ...[
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Paso',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Tramo',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Acumulado',
                                textAlign: TextAlign.end,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      ...calculation.splits.map((split) {
                        final step =
                            split.distanceMeters == calculation.distanceMeters
                            ? '${_formatDistance(split.distanceMeters)} · meta'
                            : _formatDistance(split.distanceMeters);
                        final segment =
                            '${_clock(split.segmentSeconds)} / ${_formatDistance(split.segmentMeters)}';
                        final cumulative = _clock(split.cumulativeSeconds);
                        const cumulativeStyle = TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        );
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 12 : 7,
                          ),
                          child: compact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      step,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Tramo: $segment',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      'Acumulado: $cumulative',
                                      style: cumulativeStyle,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text(step)),
                                    Expanded(
                                      child: Text(
                                        segment,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        cumulative,
                                        textAlign: TextAlign.end,
                                        style: cumulativeStyle,
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = totalSeconds % 3600 ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

String _number(double value) => value
    .toStringAsFixed(4)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '')
    .replaceAll('.', ',');

String _formatDistance(double meters) =>
    meters >= 1000 ? '${_number(meters / 1000)} km' : '${_number(meters)} m';

String _paceLabel(double seconds) {
  final rounded = seconds.round();
  if (rounded == 0) return '<0:01/km';
  final prefix = seconds == rounded ? '' : '≈ ';
  return '$prefix${_clock(rounded)}/km';
}
