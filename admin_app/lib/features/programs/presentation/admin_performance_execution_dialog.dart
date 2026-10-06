import 'package:flutter/material.dart';
import 'package:workout_core/performance_progression_policy.dart';
import 'package:workout_core/strength_exercise_catalog.dart';

/// Captura manual de una ejecución ficticia; no clasifica su respuesta deportiva.
class AdminPerformanceExecutionDialog extends StatefulWidget {
  const AdminPerformanceExecutionDialog({
    super.key,
    required this.id,
    required this.label,
    required this.dose,
    required this.date,
    this.initial,
  });

  final String id;
  final String label;
  final PerformanceProgressionDose dose;
  final DateTime date;
  final PerformanceProgressionExposure? initial;

  @override
  State<AdminPerformanceExecutionDialog> createState() =>
      _AdminPerformanceExecutionDialogState();
}

class _AdminPerformanceExecutionDialogState
    extends State<AdminPerformanceExecutionDialog> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _units;
  late final List<TextEditingController> _loads;
  late final List<bool?> _technique;
  late final List<double?> _rir;
  late final TextEditingController _bodyMass;
  late DateTime _date;
  bool? _tolerated;
  bool? _conditions;
  late PerformanceExecutionStop _stop;

  bool get _isDuration =>
      widget.dose.model == PerformanceProgressionModel.duration;
  bool get _isLoad =>
      widget.dose.model == PerformanceProgressionModel.loadAndRepetitions;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.performedOn ?? widget.date;
    _tolerated = initial?.tolerated;
    _conditions = initial?.conditionsConfirmed;
    _stop = initial?.stop ?? PerformanceExecutionStop.unknown;
    final sets = initial?.sets ?? const <PerformanceProgressionSet>[];
    _units = [
      for (var i = 0; i < widget.dose.targets.length; i++)
        TextEditingController(
          text: i < sets.length ? '${sets[i].validUnits ?? ''}' : '',
        ),
    ];
    _loads = [
      for (var i = 0; i < widget.dose.targets.length; i++)
        TextEditingController(
          text: i < sets.length ? '${sets[i].actualLoadKg ?? ''}' : '',
        ),
    ];
    _technique = [
      for (var i = 0; i < widget.dose.targets.length; i++)
        i < sets.length ? sets[i].techniqueValid : null,
    ];
    _rir = [
      for (var i = 0; i < widget.dose.targets.length; i++)
        i < sets.length ? sets[i].rir : null,
    ];
    _bodyMass = TextEditingController(
      text: '${initial?.actualBodyMassKg ?? ''}',
    );
  }

  @override
  void dispose() {
    for (final controller in [..._units, ..._loads, _bodyMass]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _decimal(String text) => double.tryParse(text.replaceAll(',', '.'));

  String? _validateLoad(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = _decimal(value);
    return number == null || !number.isFinite || number <= 0
        ? 'Introduce kilos mayores que cero.'
        : null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      PerformanceProgressionExposure(
        id: widget.id,
        performedOn: _date,
        dose: widget.dose,
        conditionsConfirmed: _conditions,
        actualBodyMassKg: _decimal(_bodyMass.text),
        tolerated: _tolerated,
        stop: _stop,
        sets: [
          for (var i = 0; i < _units.length; i++)
            PerformanceProgressionSet(
              validUnits: int.tryParse(_units[i].text.trim()),
              techniqueValid: _technique[i],
              rir: _isDuration ? null : _rir[i],
              actualLoadKg: _isLoad ? _decimal(_loads[i].text) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now().toUtc();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 14)),
      lastDate: today,
    );
    if (date != null && mounted) {
      // Solo se declara el día: no inventamos una hora que pueda ser futura.
      setState(() => _date = DateTime.utc(date.year, date.month, date.day));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Registrar ejecución · ${widget.label}'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Registro ficticio del laboratorio. Completa lo que ocurrió; lo desconocido se deja sin informar.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
              ),
              const SizedBox(height: 8),
              Text(
                'Pautado: ${widget.dose.targets.join(' / ')} ${_isDuration ? 'segundos' : 'repeticiones'}${_isLoad ? ' · ${widget.dose.loadKg} kg' : ''}. Descanso: ${widget.dose.restSeconds} s${_isDuration ? '.' : ' · margen objetivo: ${widget.dose.targetRir} (RIR).'}',
              ),
              if (!_isDuration)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Margen real: cuántas repeticiones más crees que podrías haber hecho seguidas, con buena técnica y sin descansar. No copies el objetivo si no lo sabes.',
                  ),
                ),
              for (var i = 0; i < _units.length; i++) ...[
                const Divider(height: 24),
                Text(
                  'Serie ${i + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextFormField(
                  key: ValueKey('actual_units_$i'),
                  controller: _units[i],
                  decoration: InputDecoration(
                    labelText: _isDuration
                        ? 'Segundos mantenidos'
                        : 'Repeticiones realizadas',
                    hintText: 'Sin informar',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = int.tryParse(value.trim());
                    return number == null || number < 0 || number > 3600
                        ? 'Introduce un entero entre 0 y 3600.'
                        : null;
                  },
                ),
                if (_isLoad)
                  TextFormField(
                    key: ValueKey('actual_load_$i'),
                    controller: _loads[i],
                    decoration: const InputDecoration(
                      labelText: 'Carga externa utilizada (kg)',
                      hintText: 'Sin informar',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateLoad,
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey('technique_$i'),
                  initialValue: _technique[i] == null
                      ? 'unknown'
                      : '${_technique[i]}',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '¿Mantuviste la técnica válida?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'unknown',
                      child: Text('Sin informar'),
                    ),
                    DropdownMenuItem(value: 'true', child: Text('Sí')),
                    DropdownMenuItem(value: 'false', child: Text('No')),
                  ],
                  onChanged: (value) => _technique[i] = value == 'unknown'
                      ? null
                      : value == 'true',
                ),
                if (!_isDuration)
                  DropdownButtonFormField<double>(
                    key: ValueKey('actual_rir_$i'),
                    initialValue: _rir[i] ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Repeticiones que te quedaban (RIR real)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('No sé estimarlo'),
                      ),
                      for (var value = 0; value <= 20; value++)
                        DropdownMenuItem(
                          value: value / 2,
                          child: Text('${value / 2}'),
                        ),
                    ],
                    onChanged: (value) => _rir[i] = value == -1 ? null : value,
                  ),
              ],
              const Divider(height: 24),
              if (widget.dose.loadMode ==
                  StrengthLoadMode.bodyweightPlusExternal)
                TextFormField(
                  controller: _bodyMass,
                  decoration: const InputDecoration(
                    labelText:
                        'Masa corporal declarada para esta ejecución (kg)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateLoad,
                ),
              CheckboxListTile(
                key: const ValueKey('execution_conditions'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Se mantuvieron la variante, el montaje y los descansos pautados',
                ),
                value: _conditions == true,
                onChanged: (value) => setState(() => _conditions = value),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('execution_tolerance'),
                initialValue: _tolerated == null ? 'unknown' : '$_tolerated',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '¿El trabajo fue tolerable?',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'unknown',
                    child: Text('Sin informar'),
                  ),
                  DropdownMenuItem(value: 'true', child: Text('Sí, tolerable')),
                  DropdownMenuItem(
                    value: 'false',
                    child: Text('No, hubo dificultad'),
                  ),
                ],
                onChanged: (value) =>
                    _tolerated = value == 'unknown' ? null : value == 'true',
              ),
              DropdownButtonFormField<PerformanceExecutionStop>(
                key: const ValueKey('execution_stop'),
                initialValue: _stop,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Interrupción del trabajo',
                ),
                items: const [
                  DropdownMenuItem(
                    value: PerformanceExecutionStop.unknown,
                    child: Text('No lo he indicado'),
                  ),
                  DropdownMenuItem(
                    value: PerformanceExecutionStop.none,
                    child: Text('Sin interrupción'),
                  ),
                  DropdownMenuItem(
                    value: PerformanceExecutionStop.time,
                    child: Text('Falta de tiempo'),
                  ),
                  DropdownMenuItem(
                    value: PerformanceExecutionStop.difficulty,
                    child: Text('Dificultad física'),
                  ),
                ],
                onChanged: (value) => _stop = value!,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar registro')),
    ],
  );
}
