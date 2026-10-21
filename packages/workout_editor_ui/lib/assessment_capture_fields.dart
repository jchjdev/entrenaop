import 'package:flutter/material.dart';
import 'package:workout_core/professional_assessment.dart';

/// Captura deportiva común: una marca válida de cero es un hecho; un intento
/// nulo se declara expresamente y no recibe una marca de cero por defecto.
class AssessmentCaptureFields extends StatefulWidget {
  const AssessmentCaptureFields({
    super.key,
    required this.form,
    required this.onChanged,
    this.initialAnswers = const {},
    this.readOnly = false,
  });
  final ProfessionalAssessmentVersion form;
  final Map<String, List<ProfessionalAssessmentAttempt>> initialAnswers;
  final ValueChanged<Map<String, List<ProfessionalAssessmentAttempt>>>
  onChanged;
  final bool readOnly;
  @override
  State<AssessmentCaptureFields> createState() =>
      _AssessmentCaptureFieldsState();
}

class _AttemptFields {
  _AttemptFields([ProfessionalAssessmentAttempt? attempt])
    : valid = attempt?.valid ?? true,
      text = TextEditingController(text: attempt?.value?.toString());
  bool valid;
  final TextEditingController text;
  String? error;
}

class _AssessmentCaptureFieldsState extends State<AssessmentCaptureFields> {
  final _fields = <String, List<_AttemptFields>>{};
  final _touched = <String>{};
  @override
  void initState() {
    super.initState();
    for (final test in widget.form.tests) {
      final initial = widget.initialAnswers[test.id];
      _fields[test.id] = initial == null || initial.isEmpty
          ? [_AttemptFields()]
          : initial.map(_AttemptFields.new).toList();
      if (initial != null && initial.isNotEmpty) _touched.add(test.id);
    }
  }

  @override
  void dispose() {
    for (final attempts in _fields.values) {
      for (final field in attempts) {
        field.text.dispose();
      }
    }
    super.dispose();
  }

  void _emit(String id) {
    _touched.add(id);
    final answers = <String, List<ProfessionalAssessmentAttempt>>{};
    for (final test in widget.form.tests.where(
      (t) => _touched.contains(t.id),
    )) {
      answers[test.id] = _fields[test.id]!
          .map((field) {
            double? value;
            field.error = null;
            if (field.valid && field.text.text.trim().isNotEmpty) {
              try {
                value = ProfessionalAssessmentValidator.parseMark(
                  field.text.text,
                  test,
                );
              } on FormatException catch (e) {
                field.error = e.message;
              }
            }
            return ProfessionalAssessmentAttempt(
              valid: field.valid,
              value: field.valid ? value : null,
            );
          })
          .toList(growable: false);
    }
    widget.onChanged(answers);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final test in widget.form.tests)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(test.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  test.source == ProfessionalProtocolSource.custom
                      ? 'Protocolo privado del preparador'
                      : 'Protocolo de catálogo publicado · marca de entrenamiento',
                ),
                Text(test.instructions),
                Text(
                  'Resolución: ${test.resolution} ${_unit(test.unit)} · hasta ${test.maximumAttempts} intentos · ${_policy(test.retryPolicy)}',
                ),
                for (final indexed in _fields[test.id]!.indexed) ...[
                  const SizedBox(height: 12),
                  Text('Intento ${indexed.$1 + 1}'),
                  DropdownButtonFormField<bool>(
                    initialValue: indexed.$2.valid,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Validez del intento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: true,
                        child: Text('Válido: registrar marca'),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Nulo: sin marca válida'),
                      ),
                    ],
                    onChanged: widget.readOnly
                        ? null
                        : (valid) {
                            if (valid == null) return;
                            indexed.$2.valid = valid;
                            _emit(test.id);
                          },
                  ),
                  TextField(
                    controller: indexed.$2.text,
                    readOnly: widget.readOnly,
                    enabled: indexed.$2.valid,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Marca (${_unit(test.unit)})',
                      errorText: indexed.$2.error,
                      helperText: test.unit == ProfessionalMarkUnit.seconds
                          ? 'Segundos o m:ss; se conserva la precisión.'
                          : 'Sin separadores de miles.',
                    ),
                    onChanged: (_) => _emit(test.id),
                  ),
                ],
                if (!widget.readOnly)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed:
                            _fields[test.id]!.length >= test.maximumAttempts ||
                                (test.retryPolicy ==
                                        ProfessionalRetryPolicy.invalidOnly &&
                                    _fields[test.id]!.any((a) => a.valid))
                            ? null
                            : () {
                                _fields[test.id]!.add(_AttemptFields());
                                _emit(test.id);
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir intento'),
                      ),
                      if (_fields[test.id]!.length > 1)
                        TextButton(
                          onPressed: () {
                            final removed = _fields[test.id]!.removeLast();
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => removed.text.dispose(),
                            );
                            _emit(test.id);
                          },
                          child: const Text('Quitar último intento'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
    ],
  );
  String _unit(ProfessionalMarkUnit unit) => switch (unit) {
    ProfessionalMarkUnit.repetitions => 'rep',
    ProfessionalMarkUnit.seconds => 's',
    ProfessionalMarkUnit.meters => 'm',
  };
  String _policy(ProfessionalRetryPolicy policy) => switch (policy) {
    ProfessionalRetryPolicy.none => 'sin repetición',
    ProfessionalRetryPolicy.always => 'repetición libre',
    ProfessionalRetryPolicy.invalidOnly => 'solo repetir tras nulo',
  };
}
