import 'package:entrenaop/features/running_tools/domain/services/running_pace_calculator.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RunningPaceCalculatorPage extends StatefulWidget {
  const RunningPaceCalculatorPage({super.key});

  @override
  State<RunningPaceCalculatorPage> createState() =>
      _RunningPaceCalculatorPageState();
}

class _RunningPaceCalculatorPageState extends State<RunningPaceCalculatorPage> {
  static const _calculator = RunningPaceCalculator();
  static const _presetDistances = [
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
  static const _splitOptions = [100, 200, 400, 500, 1000];

  final _paceController = TextEditingController(text: '3:40');
  final _distanceController = TextEditingController(text: '400');
  int? _selectedDistance = 400;
  int? _selectedSplit;

  @override
  void dispose() {
    _paceController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  int? get _distance => int.tryParse(_distanceController.text);

  int _automaticSplit(int distance) {
    if (distance <= 200) return distance;
    if (distance <= 500) return 100;
    if (distance <= 1000) return 200;
    return 400;
  }

  RunningPaceCalculation? get _calculation {
    final pace = parseDurationInput(_paceController.text);
    final distance = _distance;
    if (pace == null ||
        pace <= 0 ||
        distance == null ||
        distance < 1 ||
        distance > 2000) {
      return null;
    }
    return _calculator.calculate(
      paceSecondsPerKilometer: pace,
      distanceMeters: distance,
      splitMeters: _selectedSplit ?? _automaticSplit(distance),
    );
  }

  void _selectDistance(int distance) {
    setState(() {
      _selectedDistance = distance;
      _distanceController.text = '$distance';
      if (_selectedSplit != null && _selectedSplit! >= distance) {
        _selectedSplit = null;
      }
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
                    'Introduce el ritmo por kilómetro y la distancia de la serie. Verás el tiempo final y los pasos acumulados que debes marcar en pista.',
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
                            key: const ValueKey('running-pace-input'),
                            controller: _paceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [DurationInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Ritmo objetivo (min:seg/km)',
                              hintText: '3:40',
                              helperText: 'Escribe, por ejemplo, 3:40',
                              prefixIcon: Icon(Icons.speed_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            key: const ValueKey('running-distance-input'),
                            controller: _distanceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Distancia de la serie',
                              suffixText: 'm',
                              helperText: distance != null && distance > 2000
                                  ? 'La distancia máxima es 2000 m'
                                  : 'Entre 1 y 2000 m',
                              errorText:
                                  distance == null ||
                                      distance < 1 ||
                                      distance > 2000
                                  ? 'Introduce una distancia válida'
                                  : null,
                              prefixIcon: const Icon(Icons.straighten_rounded),
                            ),
                            onChanged: (value) => setState(() {
                              final parsed = int.tryParse(value);
                              _selectedDistance =
                                  parsed != null &&
                                      _presetDistances.contains(parsed)
                                  ? parsed
                                  : null;
                              if (_selectedSplit != null &&
                                  (int.tryParse(value) ?? 0) <=
                                      _selectedSplit!) {
                                _selectedSplit = null;
                              }
                            }),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            children: _presetDistances
                                .map(
                                  (meters) => ChoiceChip(
                                    label: Text(
                                      meters >= 1000
                                          ? '${_compactNumber(meters / 1000)} km'
                                          : '$meters m',
                                    ),
                                    selected: _selectedDistance == meters,
                                    onSelected: (_) => _selectDistance(meters),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          if (distance != null && distance > 100) ...[
                            const SizedBox(height: 22),
                            const Text(
                              'Parciales',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedSplit == null
                                  ? 'Automático · cada ${_automaticSplit(distance)} m'
                                  : 'Cada $_selectedSplit m',
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
                                ..._splitOptions
                                    .where((split) => split < distance)
                                    .map(
                                      (split) => ChoiceChip(
                                        label: Text('$split m'),
                                        selected: _selectedSplit == split,
                                        onSelected: (_) => setState(
                                          () => _selectedSplit = split,
                                        ),
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
                    _ResultCard(calculation: calculation)
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Revisa el ritmo y la distancia para calcular la serie.',
                          style: TextStyle(color: Colors.white70),
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
  const _ResultCard({required this.calculation});

  final RunningPaceCalculation calculation;

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
            const Text(
              'Tiempo de la serie',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _clock(calculation.totalSeconds),
              key: const ValueKey('running-total-time'),
              style: const TextStyle(
                color: Color(0xFFFF8A50),
                fontSize: 42,
                height: 1,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${calculation.distanceMeters} m a ${_clock(calculation.paceSecondsPerKilometer)}/km',
              style: const TextStyle(color: Colors.white60),
            ),
            if (hasIntermediateSplits) ...[
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 8),
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
              ...calculation.splits.map(
                (split) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          split.distanceMeters == calculation.distanceMeters
                              ? '${split.distanceMeters} m · meta'
                              : '${split.distanceMeters} m',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_clock(split.segmentSeconds)} / ${split.segmentMeters} m',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _clock(split.cumulativeSeconds),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _compactNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
