import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_editor_ui/duration_input_formatter.dart';

import '../data/admin_builtin_assessment_authoring_repository.dart';

String builtinMark(int mark, String unit, String testId) {
  if (unit == 'repetitions') return '$mark repeticiones';
  final seconds = mark / 1000;
  if (testId == 'agility_speed_circuit') {
    return '${seconds.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '').replaceAll('.', ',')} s';
  }
  return formatDurationSeconds(seconds);
}

String builtinGroup(String value) => switch (value) {
  'entry' => 'Ingreso',
  'end_of_general_military_training' => 'Fin de formación militar general',
  'end_of_training' => 'Fin de formación',
  '60_plus' => '60 años o más',
  _ => '${value.replaceAll('_', '–')} años',
};

/// Edita una columna y una página de la matriz; nunca crea cientos de campos.
class AdminBuiltinAssessmentValuesEditor extends StatefulWidget {
  const AdminBuiltinAssessmentValuesEditor({
    super.key,
    required this.definition,
    required this.isFas,
    required this.enabled,
    required this.onChanged,
  });
  final Map<String, dynamic> definition;
  final bool isFas, enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  State<AdminBuiltinAssessmentValuesEditor> createState() =>
      _AdminBuiltinAssessmentValuesEditorState();
}

class _AdminBuiltinAssessmentValuesEditorState
    extends State<AdminBuiltinAssessmentValuesEditor> {
  String? _test, _group;
  String _category = 'men';
  int _page = 0;
  static const _pageSize = 20;

  @override
  void didUpdateWidget(covariant AdminBuiltinAssessmentValuesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition['version'] != widget.definition['version']) {
      _test = null;
      _group = null;
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = (widget.definition['tests'] as List).cast<Map>();
    if (tests.isEmpty) return const Text('No se han recibido las pruebas.');
    final test = tests.firstWhere(
      (test) => test['id'] == _test,
      orElse: () => tests.first,
    );
    final id = test['id'] as String;
    final groups = widget.isFas
        ? (test['ageBands'] as List?)?.cast<String>() ??
              (widget.definition['ageBands'] as List)
                  .map((row) => (row as Map)['id'] as String)
                  .toList()
        : ['entry', 'end_of_general_military_training', 'end_of_training'];
    final group = groups.contains(_group) ? _group! : groups.first;
    final shared = widget.isFas && test['categoriesPerAgeBand'] != true;
    final column = widget.isFas
        ? groups.indexOf(group) * (shared ? 1 : 2) +
              (shared || _category == 'men' ? 0 : 1)
        : 0;
    final values = <({int index, int mark, int value})>[];
    if (widget.isFas) {
      final rows = test['rows'] as List;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as List;
        values.add((
          index: i,
          mark: (row[0] as num).toInt(),
          value: ((row[1] as List)[column] as num).toInt(),
        ));
      }
    } else {
      final rows = widget.definition['standards'] as List;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as Map;
        if (row['testId'] == id &&
            row['category'] == _category &&
            row['group'] == group) {
          values.add((
            index: i,
            mark: (row['threshold'] as num).toInt(),
            value: (row['threshold'] as num).toInt(),
          ));
        }
      }
    }
    final pages = (values.length / _pageSize).ceil();
    final page = _page.clamp(0, pages > 0 ? pages - 1 : 0);
    final visible = values.skip(page * _pageSize).take(_pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isFas ? 'Tabla completa de puntuación' : 'Mínimos por hito',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('builtin-test-$id'),
          initialValue: id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Prueba'),
          items: [
            for (final row in tests)
              DropdownMenuItem(
                value: row['id'] as String,
                child: Text(
                  row['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _test = value;
            _group = null;
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!shared)
              for (final category in ['men', 'women'])
                ChoiceChip(
                  label: Text(category == 'men' ? 'Hombres' : 'Mujeres'),
                  selected: _category == category,
                  onSelected: (_) => setState(() {
                    _category = category;
                    _page = 0;
                  }),
                ),
            if (shared) const Text('Puntuación común para ambos sexos'),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('builtin-group-$id-$group'),
          initialValue: group,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.isFas ? 'Tramo de edad' : 'Hito',
          ),
          items: [
            for (final value in groups)
              DropdownMenuItem(
                value: value,
                child: Text(
                  builtinGroup(value),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _group = value;
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isFas
              ? 'Las marcas, edades y protocolos se conservan. Puedes editar los puntos de cada marca y columna.'
              : 'Las pruebas, unidades e hitos se conservan. Los cambios se aplican únicamente al borrador.',
        ),
        for (final row in visible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(builtinMark(row.mark, test['unit'] as String, id)),
                  if (widget.isFas) Text('${row.value} puntos'),
                  if (widget.enabled)
                    OutlinedButton.icon(
                      key: ValueKey('builtin-edit-$id-$column-${row.index}'),
                      onPressed: () async {
                        final value = await _editValue(
                          context,
                          value: row.value,
                          points: widget.isFas,
                          test: test,
                        );
                        if (value == null || !mounted) return;
                        final next = copyBuiltinDefinition(widget.definition);
                        if (widget.isFas) {
                          final target = (next['tests'] as List).firstWhere(
                            (test) => (test as Map)['id'] == id,
                          ) as Map;
                          final targetRow =
                              (target['rows'] as List)[row.index] as List;
                          (targetRow[1] as List)[column] = value;
                        } else {
                          ((next['standards'] as List)[row.index]
                                  as Map)['threshold'] =
                              value;
                        }
                        widget.onChanged(next);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        widget.isFas ? 'Editar puntos' : 'Editar mínimo',
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (pages > 1)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: page == 0
                    ? null
                    : () => setState(() => _page = page - 1),
                child: const Text('Filas anteriores'),
              ),
              Text('Página ${page + 1} de $pages · ${values.length} filas'),
              OutlinedButton(
                onPressed: page + 1 == pages
                    ? null
                    : () => setState(() => _page = page + 1),
                child: const Text('Filas siguientes'),
              ),
            ],
          ),
      ],
    );
  }
}

Future<int?> _editValue(
  BuildContext context, {
  required int value,
  required bool points,
  required Map test,
}) async {
  final reps = test['unit'] == 'repetitions';
  final agility = test['id'] == 'agility_speed_circuit';
  final controller = TextEditingController(
    text: points || reps
        ? value.toString()
        : agility
        ? (value / 1000).toString().replaceAll('.', ',')
        : formatDurationSeconds(value / 1000),
  );
  final form = GlobalKey<FormState>();
  int? parsed() {
    if (points || reps) return int.tryParse(controller.text.trim());
    final seconds = parsePerformanceTime(controller.text);
    if (seconds == null || seconds < 0) return null;
    final millis = seconds * 1000;
    if ((millis - millis.round()).abs() > .00001) return null;
    return millis.round();
  }

  try {
    return await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(points ? 'Editar puntos' : 'Editar mínimo'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: !points && !reps,
            ),
            inputFormatters: [
              if (points || reps) FilteringTextInputFormatter.digitsOnly,
              if (!points && !reps && !agility)
                const DurationInputFormatter(allowFraction: true),
            ],
            decoration: InputDecoration(
              labelText: points
                  ? 'Puntos (0–100)'
                  : reps
                  ? 'Repeticiones'
                  : agility
                  ? 'Segundos'
                  : 'Tiempo (min:seg)',
            ),
            validator: (_) {
              final number = parsed();
              return number == null || number < 0 || points && number > 100
                  ? points
                        ? 'Indica un entero entre 0 y 100.'
                        : 'Introduce una marca válida, con hasta tres decimales.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, parsed());
            },
            child: const Text('Aplicar al borrador'),
          ),
        ],
      ),
    );
  } finally {
    // El diálogo puede seguir completando su animación de cierre.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}
