import 'package:flutter/material.dart';
import 'package:workout_core/performance_set.dart';
import 'package:workout_core/performance_time.dart';

/// Captura manual: nunca rellena un resultado con la prescripción.
class PerformanceResultForm extends StatefulWidget {
  const PerformanceResultForm({
    required this.prescription,
    required this.onSave,
    this.initialResult,
    this.correction = false,
    this.saving = false,
    this.timer,
    this.elapsedSeconds,
    super.key,
  });
  final PerformanceSetPrescription prescription;
  final PerformanceSetResult? initialResult;
  final void Function(PerformanceSetResult result, String reason) onSave;
  final bool correction;
  final bool saving;
  final Widget? timer;
  final ValueNotifier<double>? elapsedSeconds;
  @override
  State<PerformanceResultForm> createState() => _PerformanceResultFormState();
}

class _PerformanceResultFormState extends State<PerformanceResultForm> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool? _technique, _conditions, _tolerated, _succeeded;
  String _stop = 'unknown';
  String? _error;
  PerformanceSetPrescription get p => widget.prescription;
  bool get _responses =>
      p.recordsStimulusResponses ||
      widget.initialResult?.correctResponses != null ||
      widget.initialResult?.totalResponses != null;
  bool get _penalties =>
      p.recordsPenaltySeconds || widget.initialResult?.penaltySeconds != null;
  @override
  void initState() {
    super.initState();
    final r = widget.initialResult;
    final values = <String, Object?>{
      'height': r?.jumpHeightMeters,
      'method': r?.measurementMethod,
      'window': r?.actualDurationSeconds,
      'value': r?.value,
      'load': r?.loadKg,
      'body': r?.bodyMassKg,
      'rir': r?.rir,
      'rpe': r?.rpe,
      'penalty': r?.penaltySeconds,
      'correct': r?.correctResponses,
      'total': r?.totalResponses,
      'reason': null,
    };
    for (final e in values.entries) {
      _fields[e.key] = TextEditingController(text: e.value?.toString() ?? '');
    }
    _technique = r?.techniqueValid;
    _succeeded = r?.succeeded;
    _conditions = r?.conditionsConfirmed;
    _tolerated = r?.tolerated;
    _stop = r?.stopReason ?? 'unknown';
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(String key) => parsePerformanceTime(_fields[key]!.text);
  bool get _timeValue => const [
    'DURATION',
    'TIME_FOR_DISTANCE',
    'TIME_FOR_COURSE',
  ].contains(p.measurement);
  Widget _number(
    String key,
    String label, {
    bool integer = false,
    bool time = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(
        labelText: label,
        helperText: time
            ? 'Minutos:segundos (1:30) o segundos (90). Vacío si no lo sabes.'
            : 'Déjalo vacío si no lo sabes.',
      ),
      keyboardType: time
          ? TextInputType.datetime
          : TextInputType.numberWithOptions(decimal: !integer),
      validator: (s) {
        if (s == null || s.trim().isEmpty) return null;
        final n = _n(key);
        return n == null ||
                !n.isFinite ||
                n < 0 ||
                n > 1000000 ||
                (!time && s.contains(':')) ||
                (integer && n % 1 != 0)
            ? 'Introduce un número ${integer ? 'entero ' : ''}no negativo.'
            : null;
      },
    ),
  );
  Widget _answer(String label, bool? value, ValueChanged<bool?> change) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<int>(
          key: ValueKey('$label:$value'),
          initialValue: value == null
              ? -1
              : value
              ? 1
              : 0,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: const [
            DropdownMenuItem(value: -1, child: Text('No lo sé')),
            DropdownMenuItem(value: 1, child: Text('Sí')),
            DropdownMenuItem(value: 0, child: Text('No')),
          ],
          onChanged: (v) => change(v == -1 || v == null ? null : v == 1),
        ),
      );
  void _save() {
    if (!_form.currentState!.validate()) return;
    final r = PerformanceSetResult(
      value: p.measurement == 'PASS_FAIL' ? null : _n('value'),
      succeeded: p.measurement == 'PASS_FAIL' ? _succeeded : null,
      actualDurationSeconds: p.measurement == 'REPS_IN_TIME'
          ? _n('window')
          : null,
      jumpHeightMeters: p.measurement == 'REACTIVE_METRICS'
          ? _n('height')
          : null,
      measurementMethod: p.measurement == 'REACTIVE_METRICS'
          ? _fields['method']!.text.trim()
          : null,
      techniqueValid: _technique,
      conditionsConfirmed: _conditions,
      tolerated: _tolerated,
      stopReason: _stop,
      loadKg: p.usesLoad ? _n('load') : null,
      bodyMassKg: p.needsBodyMass ? _n('body') : null,
      rir: p.usesRir ? _n('rir') : null,
      rpe: p.usesRpe ? _n('rpe') : null,
      penaltySeconds: _penalties ? _n('penalty') : null,
      correctResponses: _responses ? _n('correct')?.toInt() : null,
      totalResponses: _responses ? _n('total')?.toInt() : null,
    );
    final error = r.validate(p);
    setState(() => _error = error);
    if (error == null) widget.onSave(r, _fields['reason']!.text.trim());
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Objetivo: ${_targetLabel()}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (p.fixedDurationSeconds != null)
          Text(
            'Tiempo de trabajo: ${formatPerformanceTime(p.fixedDurationSeconds!)} min',
          ),
        if (p.fixedDistanceMeters != null)
          Text('Trayecto fijo: ${p.fixedDistanceMeters} metros'),
        if (p.externalLoadKg != null)
          Text(
            '${p.loadMode == 'assisted' ? 'Asistencia' : 'Carga externa'}: ${p.externalLoadKg} kg',
          ),
        if (p.instructions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(p.instructions),
          ),
        if (!p.setupKey.startsWith('standard:'))
          Text('Detalles para repetirlo: ${p.setupKey}'),
        if (p.intent == 'work' && p.measurement == 'DURATION') ...[
          const SizedBox(height: 8),
          const Text(
            'Termina al alcanzar el tiempo pautado con buena postura. '
            'Si pierdes la postura antes, detén la serie y registra solo los segundos válidos. '
            'El objetivo de hoy no es medir tu máximo.',
          ),
        ],
        if (widget.timer != null) widget.timer!,
        if (widget.elapsedSeconds case final elapsed?)
          ValueListenableBuilder<double>(
            valueListenable: elapsed,
            builder: (context, seconds, _) => TextButton.icon(
              icon: const Icon(Icons.timer_outlined),
              onPressed: seconds <= 0
                  ? null
                  : () {
                      // El reloj mide tiempo transcurrido; el deportista confirma si fue válido.
                      _fields[p.measurement == 'REPS_IN_TIME'
                              ? 'window'
                              : 'value']!
                          .text = formatPerformanceTime(
                        seconds,
                      );
                    },
              label: Text(
                'Usar ${formatPerformanceTime(seconds)} del temporizador',
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          p.measurement == 'TIME_FOR_COURSE' || p.intent == 'control'
              ? 'Registra tu resultado real. Si el intento fue nulo, puedes guardar la medición e indicar que la técnica no fue válida.'
              : 'Registra lo que has hecho realmente, aunque no hayas completado el objetivo. No copies el objetivo como resultado.',
        ),
        const SizedBox(height: 12),
        if (p.measurement == 'PASS_FAIL')
          _answer(
            '¿Has conseguido el intento?',
            _succeeded,
            (v) => _succeeded = v,
          )
        else
          _number(
            'value',
            _timeValue ? 'Tiempo válido realizado' : 'Resultado · ${p.unit}',
            integer: p.isIntegerValue,
            time: _timeValue,
          ),
        if (p.measurement == 'REPS_IN_TIME')
          _number('window', 'Tiempo realizado realmente', time: true),
        if (p.usesLoad)
          _number(
            'load',
            p.loadMode == 'assisted'
                ? 'Asistencia real · kg'
                : 'Carga externa real · kg',
          ),
        if (p.needsBodyMass) _number('body', 'Masa corporal actual · kg'),
        if (p.usesRir) ...[
          Text(
            'Al terminar, ¿cuántas repeticiones más podrías haber hecho con la misma técnica? '
            'Ese margen es el RIR.${p.targetRir == null ? '' : ' Conserva al menos ${p.targetRir!.toInt()}; puede quedarte más margen.'} '
            'Detén la serie si alcanzas ese esfuerzo antes del número pautado; no fuerces repeticiones con mala técnica. '
            'Si no sabes estimarlo, deja el campo vacío.',
          ),
          _number('rir', 'Repeticiones que te quedaban · 0 a 10'),
        ],
        if (p.usesRpe) ...[
          Text(
            'Esfuerzo al mantener la postura: 1 muy fácil, 5 moderado, 7 difícil pero controlado, 10 tu límite. Hoy no superes ${p.targetRpe?.toInt() ?? 7}/10.',
          ),
          _number('rpe', 'Esfuerzo que has sentido · 1 a 10'),
        ],
        if (_penalties)
          _number('penalty', 'Penalización del protocolo · segundos'),
        if (p.measurement == 'REACTIVE_METRICS') ...[
          _number('height', 'Altura medida del salto · metros'),
          TextFormField(
            controller: _fields['method'],
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Instrumento y método',
              helperText:
                  'No utilices un cronómetro manual para medir el contacto.',
            ),
          ),
        ],
        if (_responses) ...[
          const Text(
            'Solo si el protocolo exige responder a estímulos externos:',
          ),
          _number('correct', 'Respuestas correctas', integer: true),
          _number('total', 'Estímulos recibidos', integer: true),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            'Completé la pauta con buena técnica, mismas condiciones y sin molestias',
          ),
          onPressed: widget.saving
              ? null
              : () => setState(() {
                  _technique = true;
                  _conditions = true;
                  _tolerated = true;
                  _stop = 'none';
                }),
        ),
        const SizedBox(height: 12),
        _answer(
          '¿Mantuviste la técnica indicada?',
          _technique,
          (v) => _technique = v,
        ),
        const Text(
          'Para comparar sesiones, necesitamos saber si has respetado los apoyos, '
          'el material, el recorrido y los descansos indicados. '
          'Puedes guardar el resultado aunque algo haya cambiado.',
        ),
        const SizedBox(height: 8),
        _answer(
          '¿Seguiste las condiciones pautadas?',
          _conditions,
          (v) => _conditions = v,
        ),
        _answer(
          '¿Lo has tolerado sin molestias?',
          _tolerated,
          (v) => _tolerated = v,
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('stop_$_stop'),
          initialValue: _stop,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Cómo terminó la serie',
            helperText: 'Indica si acabaste lo previsto o qué te hizo parar.',
          ),
          items: const [
            DropdownMenuItem(value: 'unknown', child: Text('Sin indicar')),
            DropdownMenuItem(value: 'none', child: Text('Terminé lo previsto')),
            DropdownMenuItem(
              value: 'time',
              child: Text('Me faltó tiempo disponible'),
            ),
            DropdownMenuItem(
              value: 'difficulty',
              child: Text('No pude continuar'),
            ),
            DropdownMenuItem(
              value: 'discomfort',
              child: Text('Paré por molestias'),
            ),
          ],
          onChanged: (v) => _stop = v ?? 'unknown',
        ),
        if (widget.correction)
          TextFormField(
            controller: _fields['reason'],
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Motivo de la corrección',
            ),
            validator: (v) =>
                (v?.trim().length ?? 0) < 3 ? 'Explica el cambio.' : null,
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.saving ? null : _save,
          child: Text(
            widget.correction ? 'Guardar corrección' : 'Guardar resultado',
          ),
        ),
      ],
    ),
  );

  String _targetLabel() {
    if (p.measurement == 'PASS_FAIL') return 'un intento con técnica válida';
    if (p.measurement == 'DURATION' && p.targetValue % 1 == 0) {
      final seconds = p.targetValue.toInt();
      return seconds < 60
          ? '$seconds segundos'
          : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min';
    }
    final decimals = p.isIntegerValue || p.targetValue % 1 == 0 ? 0 : 2;
    return '${p.targetValue.toStringAsFixed(decimals)} ${p.unit}';
  }
}
