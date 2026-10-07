import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:flutter/material.dart';

String categoryLabel(String category) => switch (category) {
  'men' => 'Baremo H',
  'women' => 'Baremo M',
  _ => 'H y M',
};

String formatMark(double? value) => value == null
    ? 'Sin límite'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');

Future<AdminProgramScoringRule?> showScoringRuleDialog(
  BuildContext context,
  AdminProgramScoringRule? current, {
  required Future<void> Function(AdminProgramScoringRule) save,
}) => showDialog<AdminProgramScoringRule>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RetainedSaveDialog<AdminProgramScoringRule>(
    save: save,
    errorMessage:
        'No se pudo guardar la regla de calificación. Tus datos se conservan.',
    builder: (_, submit, saving, error, markDirty) => _ScoringRuleDialog(
      current: current,
      onSubmit: submit,
      saving: saving,
      error: error,
      onDirtyChanged: markDirty,
    ),
  ),
);

class _ScoringRuleDialog extends StatefulWidget {
  const _ScoringRuleDialog({
    this.current,
    required this.onSubmit,
    required this.saving,
    required this.error,
    required this.onDirtyChanged,
  });

  final ValueChanged<AdminProgramScoringRule> onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final bool saving;
  final String? error;

  final AdminProgramScoringRule? current;

  @override
  State<_ScoringRuleDialog> createState() => _ScoringRuleDialogState();
}

class _ScoringRuleDialogState extends State<_ScoringRuleDialog> {
  final _form = GlobalKey<FormState>();
  late final _version = TextEditingController(text: widget.current?.version);
  late final _source = TextEditingController(text: widget.current?.sourceUrl);
  late final _sourceLabel = TextEditingController(
    text: widget.current?.sourceLabel,
  );
  late final _max = TextEditingController(
    text: widget.current?.maxPoints.toString() ?? '10',
  );
  late final _each = TextEditingController(
    text: widget.current?.minEachPoints.toString() ?? '1',
  );
  late final _aggregate = TextEditingController(
    text: widget.current?.minAggregatePoints.toString() ?? '5',
  );
  late final _stage = TextEditingController(
    text: widget.current?.stageLabel ?? 'Ingreso',
  );
  late final _effective = TextEditingController(
    text: widget.current?.effectiveOn,
  );
  late final _expires = TextEditingController(text: widget.current?.expiresOn);
  late final _ageReferenceOn = TextEditingController(
    text: widget.current?.ageReferenceOn,
  );
  late String _method = widget.current?.aggregation ?? 'average';
  late String _mode = widget.current?.scoringMode ?? 'points';
  late String _ageReference = widget.current?.ageReference ?? 'assessment_date';

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot;
  }

  @override
  void dispose() {
    for (final controller in [
      _version,
      _source,
      _sourceLabel,
      _max,
      _each,
      _aggregate,
      _stage,
      _effective,
      _expires,
      _ageReferenceOn,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  late final String _initialSnapshot;
  String get _snapshot => jsonEncode([
    _version.text,
    _source.text,
    _sourceLabel.text,
    _max.text,
    _each.text,
    _aggregate.text,
    _stage.text,
    _effective.text,
    _expires.text,
    _ageReferenceOn.text,
    _method,
    _mode,
    _ageReference,
  ]);
  void _markDirty() => widget.onDirtyChanged(_snapshot != _initialSnapshot);
  void _change(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Calificación del programa'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _form,
        onChanged: _markDirty,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Text(
                'Define cómo se aprueba este programa. Después podrás crear sus pruebas y sus baremos desde aquí.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Cómo se evalúa'),
                items: const [
                  DropdownMenuItem(
                    value: 'pass_fail',
                    child: Text('Apto / no apto por mínimos'),
                  ),
                  DropdownMenuItem(
                    value: 'points',
                    child: Text('Puntos por marcas'),
                  ),
                ],
                onChanged: (value) => _change(() {
                  _mode = value ?? _mode;
                  if (_mode == 'pass_fail') {
                    _method = 'none';
                  }
                  if (_mode == 'points' && _method == 'none') {
                    _method = 'average';
                  }
                }),
              ),
              TextFormField(
                controller: _stage,
                decoration: const InputDecoration(
                  labelText: 'Modalidad o fase',
                  hintText: 'Ej.: Ingreso sin titulación',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'Indica la modalidad.' : null,
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _ageReference,
                decoration: const InputDecoration(
                  labelText: 'Edad que usa el baremo',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'assessment_date',
                    child: Text('Edad el día de la prueba'),
                  ),
                  DropdownMenuItem(
                    value: 'reference_date',
                    child: Text('Fecha oficial de referencia'),
                  ),
                  DropdownMenuItem(
                    value: 'calendar_year',
                    child: Text('Edad que cumple durante el año'),
                  ),
                ],
                onChanged: (value) =>
                    _change(() => _ageReference = value ?? _ageReference),
              ),
              if (_ageReference == 'reference_date')
                TextFormField(
                  controller: _ageReferenceOn,
                  decoration: const InputDecoration(
                    labelText: 'Fecha oficial para calcular la edad',
                    hintText: 'AAAA-MM-DD',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indica la fecha oficial.'
                      : _dateValidator(value),
                ),
              TextFormField(
                controller: _effective,
                decoration: const InputDecoration(
                  labelText: 'Vigente desde (opcional)',
                  hintText: 'AAAA-MM-DD',
                ),
                validator: _dateValidator,
              ),
              TextFormField(
                controller: _expires,
                decoration: const InputDecoration(
                  labelText: 'Vigente hasta (opcional)',
                  hintText: 'AAAA-MM-DD',
                ),
                validator: _dateValidator,
              ),
              TextFormField(
                controller: _version,
                decoration: const InputDecoration(
                  labelText: 'Versión del baremo',
                  hintText: 'Ej.: boe_cnp_2026_v1',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'Indica la versión.' : null,
              ),
              TextFormField(
                controller: _sourceLabel,
                decoration: const InputDecoration(
                  labelText: 'Fuente oficial',
                  hintText: 'Ej.: BOE-A-2026-15055, anexo II',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'Indica la fuente.' : null,
              ),
              TextFormField(
                controller: _source,
                decoration: const InputDecoration(labelText: 'Enlace oficial'),
                keyboardType: TextInputType.url,
                validator: (v) {
                  final uri = Uri.tryParse(v?.trim() ?? '');
                  return uri == null ||
                          uri.scheme != 'https' ||
                          !uri.hasAuthority ||
                          uri.host.isEmpty
                      ? 'Introduce un enlace https válido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              if (_mode == 'points')
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Resultado conjunto',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'average',
                      child: Text('Media de las pruebas'),
                    ),
                    DropdownMenuItem(
                      value: 'sum',
                      child: Text('Suma de las pruebas'),
                    ),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('Solo mínimos por prueba'),
                    ),
                  ],
                  onChanged: (v) => _change(() => _method = v ?? _method),
                ),
              const SizedBox(height: 12),
              if (_mode == 'points')
                for (final field in [
                  (_max, 'Puntos máximos por prueba'),
                  (_each, 'Mínimo obligatorio en cada prueba'),
                  if (_method != 'none')
                    (_aggregate, 'Mínimo de la media o suma'),
                ])
                  TextFormField(
                    controller: field.$1,
                    decoration: InputDecoration(labelText: field.$2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => _number(v) == null
                        ? 'Introduce un número no negativo.'
                        : null,
                  ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final max = _mode == 'points' ? _number(_max.text)! : 1.0;
          final each = _mode == 'points' ? _number(_each.text)! : 0.0;
          final aggregate = _mode == 'points' && _method != 'none'
              ? _number(_aggregate.text)!
              : 0.0;
          if (max <= 0 ||
              each > max ||
              (_method == 'average' && aggregate > max)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Revisa los límites de puntuación.'),
              ),
            );
            return;
          }
          final effective = DateTime.tryParse(_effective.text.trim());
          final expires = DateTime.tryParse(_expires.text.trim());
          if (effective != null &&
              expires != null &&
              effective.isAfter(expires)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La vigencia final no puede ser anterior a la inicial.',
                ),
              ),
            );
            return;
          }
          widget.onSubmit(
            AdminProgramScoringRule(
              version: _version.text.trim(),
              sourceUrl: _source.text.trim(),
              sourceLabel: _sourceLabel.text.trim(),
              aggregation: _method,
              maxPoints: max,
              minEachPoints: each,
              minAggregatePoints: aggregate,
              scoringMode: _mode,
              ageReference: _ageReference,
              ageReferenceOn: _ageReference == 'reference_date'
                  ? _ageReferenceOn.text.trim()
                  : null,
              stageLabel: _stage.text.trim(),
              effectiveOn: _effective.text.trim().isEmpty
                  ? null
                  : _effective.text.trim(),
              expiresOn: _expires.text.trim().isEmpty
                  ? null
                  : _expires.text.trim(),
            ),
          );
        },
        child: Text(widget.saving ? 'Guardando…' : 'Guardar regla'),
      ),
    ],
  );
}

String? _dateValidator(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final date = DateTime.tryParse(value);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
          date != null &&
          date.toIso8601String().startsWith(value)
      ? null
      : 'Usa una fecha válida AAAA-MM-DD.';
}

double? _number(String? raw) {
  final value = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  return value != null && value.isFinite && value >= 0 ? value : null;
}

List<AdminScoreBand> parseScoreBandsTable(String text, AdminProgramTest test) {
  final result = <AdminScoreBand>[];
  final lines = text.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.contains('\t') ? line.split('\t') : line.split(';');
    if (parts.length != 6) {
      throw FormatException(
        'Fila ${index + 1}: usa seis columnas separadas por ; o tabulador.',
      );
    }
    final rawCategory = parts[0].trim().toLowerCase();
    final category = switch (rawCategory) {
      'h' || 'hombre' || 'hombres' || 'men' => 'men',
      'm' || 'mujer' || 'mujeres' || 'women' => 'women',
      _ => '',
    };
    final minAge = int.tryParse(parts[1].trim());
    final maxAge = int.tryParse(parts[2].trim());
    double? mark(String raw) => raw.trim().isEmpty || raw.trim() == '*'
        ? null
        : double.tryParse(raw.trim().replaceAll(',', '.'));
    final minMark = mark(parts[3]);
    final maxMark = mark(parts[4]);
    final points = double.tryParse(parts[5].trim().replaceAll(',', '.'));
    if (category.isEmpty ||
        (test.category != 'both' && test.category != category) ||
        minAge == null ||
        maxAge == null ||
        minAge < test.minAge ||
        maxAge > test.maxAge ||
        minAge > maxAge ||
        (minMark == null && maxMark == null) ||
        (minMark != null && (!minMark.isFinite || minMark < 0)) ||
        (maxMark != null && (!maxMark.isFinite || maxMark < 0)) ||
        (minMark != null && maxMark != null && minMark > maxMark) ||
        points == null ||
        !points.isFinite ||
        points < 0) {
      throw FormatException(
        'Fila ${index + 1}: revisa columna H/M, edades, marcas y puntos.',
      );
    }
    result.add(
      AdminScoreBand(
        category: category,
        minAge: minAge,
        maxAge: maxAge,
        minMark: minMark,
        maxMark: maxMark,
        points: points,
      ),
    );
  }
  if (result.isEmpty || result.length > 2000) {
    throw const FormatException('Pega entre 1 y 2000 filas de baremo.');
  }
  return result;
}

class AdminTestScoreBandsPage extends StatefulWidget {
  const AdminTestScoreBandsPage({
    super.key,
    required this.programId,
    required this.test,
    required this.repository,
    required this.editable,
  });

  final String programId;
  final AdminProgramTest test;
  final AdminProgramRepository repository;
  final bool editable;

  @override
  State<AdminTestScoreBandsPage> createState() =>
      _AdminTestScoreBandsPageState();
}

class _AdminTestScoreBandsPageState extends State<AdminTestScoreBandsPage> {
  late Future<List<AdminScoreBand>> _bands = widget.repository.listScoreBands(
    widget.test.id,
  );
  late final Future<AdminProgramScoringRule?> _rule = widget.repository
      .getScoringRule(widget.programId);
  bool _saving = false;

  Future<void> _import() async {
    final rows = await showDialog<List<AdminScoreBand>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<List<AdminScoreBand>>(
        errorMessage: 'No se importó la tabla. Revisa solapes, resolución y máximo de puntos. Tus filas se conservan.',
        save: (rows) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Revisar ${rows.length} tramos'),
              content: Text(
                'Se sustituirán todos los tramos actuales de ${widget.test.name}. '
                'Primera fila: ${categoryLabel(rows.first.category)}, '
                '${rows.first.minAge}–${rows.first.maxAge} años, '
                '${formatMark(rows.first.minMark)}–${formatMark(rows.first.maxMark)} = '
                '${formatMark(rows.first.points)} puntos. Si una fila falla, no se cambia ninguna.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Importar y sustituir'),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) {
            throw const RetainedSaveCancelled();
          }
          await widget.repository.importScoreBands(
            widget.test.id,
            rows,
            replace: true,
          );
        },
        builder: (_, submit, saving, error, markDirty) =>
            _ScoreBandImportDialog(
              test: widget.test,
              onSubmit: submit,
              saving: saving,
              error: error,
              onDirtyChanged: markDirty,
            ),
      ),
    );
    if (rows == null || !mounted) return;
    setState(() {
      _bands = widget.repository.listScoreBands(widget.test.id);
      _bands.ignore();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} tramos importados.')),
    );
  }

  Future<void> _add() => _editBand();

  Future<void> _edit(AdminScoreBand current) => _editBand(current);

  Future<void> _editBand([AdminScoreBand? current]) async {
    final band = await showDialog<AdminScoreBand>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<AdminScoreBand>(
        save: (value) => current == null
            ? widget.repository.addScoreBand(widget.test.id, value)
            : widget.repository.updateScoreBand(widget.test.id, value),
        errorMessage: 'No se pudo guardar el tramo. Revisa límites, puntos, solapamientos y la regla general. Tus datos se conservan.',
        builder: (_, submit, saving, error, markDirty) => _ScoreBandDialog(
          test: widget.test,
          existing: current,
          onSubmit: submit,
          saving: saving,
          error: error,
          onDirtyChanged: markDirty,
        ),
      ),
    );
    if (band == null || !mounted) return;
    setState(() {
      _bands = widget.repository.listScoreBands(widget.test.id);
      _bands.ignore();
    });
  }

  Future<void> _delete(AdminScoreBand band) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar tramo'),
        content: Text(
          '¿Quitar el tramo ${formatMark(band.minMark)}–${formatMark(band.maxMark)} de ${categoryLabel(band.category)}? El baremo quedará incompleto hasta que lo sustituyas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteScoreBand(band.id);
      if (!mounted) return;
      setState(() {
        _bands = widget.repository.listScoreBands(widget.test.id);
        _bands.ignore();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar este tramo.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Baremo · ${widget.test.name}')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.test.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ejercicio ${widget.test.displayOrder} · ${categoryLabel(widget.test.category)} · resolución ${formatMark(widget.test.markStep)}',
            ),
            const SizedBox(height: 12),
            Text(widget.test.protocolNotes),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Tramos de puntuación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.editable) ...[
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _import,
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('Pegar tabla'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir tramo'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Los extremos se incluyen. Deja uno vacío para representar «o menos» u «o más». Los tramos no pueden solaparse.',
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AdminScoreBand>>(
              future: _bands,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(() {
                      _bands = widget.repository.listScoreBands(widget.test.id);
                      _bands.ignore();
                    }),
                    child: const Text(
                      'No se pudo cargar el baremo. Reintentar',
                    ),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Todavía no hay tramos. El programa no está listo para puntuar.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    FutureBuilder<AdminProgramScoringRule?>(
                      future: _rule,
                      builder: (context, ruleSnapshot) =>
                          ruleSnapshot.data == null
                          ? const SizedBox.shrink()
                          : _ThresholdSummary(
                              test: widget.test,
                              bands: snapshot.data!,
                              rule: ruleSnapshot.data!,
                            ),
                    ),
                    for (final band in snapshot.data!)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${formatMark(band.minMark)} – ${formatMark(band.maxMark)} · ${formatMark(band.points)} puntos',
                          ),
                          subtitle: Text(
                            '${categoryLabel(band.category)} · ${band.minAge}–${band.maxAge} años',
                          ),
                          trailing: widget.editable
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar tramo',
                                      onPressed: _saving
                                          ? null
                                          : () => _edit(band),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar tramo',
                                      onPressed: _saving
                                          ? null
                                          : () => _delete(band),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThresholdSummary extends StatelessWidget {
  const _ThresholdSummary({
    required this.test,
    required this.bands,
    required this.rule,
  });

  final AdminProgramTest test;
  final List<AdminScoreBand> bands;
  final AdminProgramScoringRule rule;

  double? _threshold(String category, int minAge, int maxAge, double points) {
    final eligible = bands.where(
      (b) =>
          b.category == category &&
          b.minAge == minAge &&
          b.maxAge == maxAge &&
          b.points >= points,
    );
    final boundaries = eligible
        .map((b) => test.betterDirection == 'higher' ? b.minMark : b.maxMark)
        .whereType<double>()
        .toList();
    if (boundaries.isEmpty) return null;
    boundaries.sort();
    return test.betterDirection == 'higher'
        ? boundaries.first
        : boundaries.last;
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marcas clave del baremo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Mínimo por prueba: ${formatMark(rule.minEachPoints)} puntos · máxima puntuación: ${formatMark(rule.maxPoints)} puntos',
          ),
          const SizedBox(height: 8),
          for (final group
              in bands.map((b) => (b.category, b.minAge, b.maxAge)).toSet())
            if (test.category == 'both' || test.category == group.$1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${categoryLabel(group.$1)} · ${group.$2}–${group.$3} años · mínimo para puntuar: ${_threshold(group.$1, group.$2, group.$3, rule.minEachPoints) == null ? 'sin definir' : formatMark(_threshold(group.$1, group.$2, group.$3, rule.minEachPoints))} · marca para ${formatMark(rule.maxPoints)} puntos: ${_threshold(group.$1, group.$2, group.$3, rule.maxPoints) == null ? 'sin definir' : formatMark(_threshold(group.$1, group.$2, group.$3, rule.maxPoints))} ${test.unit == 'seconds'
                      ? 's'
                      : test.unit == 'meters'
                      ? 'm'
                      : 'reps'}',
                ),
              ),
        ],
      ),
    ),
  );
}

class _ScoreBandDialog extends StatefulWidget {
  const _ScoreBandDialog({
    required this.test,
    this.existing,
    required this.onSubmit,
    required this.saving,
    required this.error,
    required this.onDirtyChanged,
  });

  final ValueChanged<AdminScoreBand> onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final bool saving;
  final String? error;

  final AdminProgramTest test;
  final AdminScoreBand? existing;

  @override
  State<_ScoreBandDialog> createState() => _ScoreBandDialogState();
}

class _ScoreBandImportDialog extends StatefulWidget {
  const _ScoreBandImportDialog({
    required this.test,
    required this.onSubmit,
    required this.saving,
    required this.error,
    required this.onDirtyChanged,
  });
  final ValueChanged<List<AdminScoreBand>> onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final bool saving;
  final String? error;
  final AdminProgramTest test;
  @override
  State<_ScoreBandImportDialog> createState() => _ScoreBandImportDialogState();
}

class _ScoreBandImportDialogState extends State<_ScoreBandImportDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pegar tabla de puntos'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.error != null)
              Text(
                widget.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Text(
              'Copia filas desde una hoja de cálculo. Separa las columnas con punto y coma o tabulador.',
            ),
            const SizedBox(height: 10),
            const SelectableText(
              'H/M ; edad desde ; edad hasta ; marca desde ; marca hasta ; puntos',
            ),
            const SizedBox(height: 6),
            const SelectableText('H;18;34;0;4;0\nH;18;34;5;*;1'),
            const SizedBox(height: 6),
            const Text(
              'Usa * para un extremo abierto. Puedes escribir decimales con coma.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 12,
              minLines: 8,
              decoration: InputDecoration(
                labelText: 'Filas del baremo',
                errorText: _error,
              ),
              onChanged: (_) {
                widget.onDirtyChanged(_text.text.isNotEmpty);
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final rows = parseScoreBandsTable(_text.text, widget.test);
            widget.onSubmit(rows);
          } on FormatException catch (error) {
            setState(() => _error = error.message);
          }
        },
        child: Text(widget.saving ? 'Revisando…' : 'Revisar filas'),
      ),
    ],
  );
}

class _ScoreBandDialogState extends State<_ScoreBandDialog> {
  final _form = GlobalKey<FormState>();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _points = TextEditingController();
  final _minAge = TextEditingController();
  final _maxAge = TextEditingController();
  late String _category = widget.test.category == 'women' ? 'women' : 'men';

  @override
  void initState() {
    super.initState();
    final band = widget.existing;
    if (band == null) {
      _initialSnapshot = _snapshot;
      return;
    }
    _category = band.category;
    _min.text = band.minMark == null ? '' : formatMark(band.minMark);
    _max.text = band.maxMark == null ? '' : formatMark(band.maxMark);
    _points.text = formatMark(band.points);
    _minAge.text = band.minAge.toString();
    _maxAge.text = band.maxAge.toString();
    _initialSnapshot = _snapshot;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _points.dispose();
    _minAge.dispose();
    _maxAge.dispose();
    super.dispose();
  }

  late final String _initialSnapshot;
  String get _snapshot => jsonEncode([
    _min.text,
    _max.text,
    _points.text,
    _minAge.text,
    _maxAge.text,
    _category,
  ]);
  void _markDirty() => widget.onDirtyChanged(_snapshot != _initialSnapshot);
  void _change(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Añadir tramo' : 'Editar tramo'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _form,
        onChanged: _markDirty,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Columna del baremo',
                ),
                items: [
                  if (widget.test.category != 'women')
                    const DropdownMenuItem(
                      value: 'men',
                      child: Text('Hombres'),
                    ),
                  if (widget.test.category != 'men')
                    const DropdownMenuItem(
                      value: 'women',
                      child: Text('Mujeres'),
                    ),
                ],
                onChanged: (v) => _change(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minAge,
                decoration: const InputDecoration(
                  labelText: 'Edad desde',
                  helperText: 'Vacío: desde la edad mínima de la prueba',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _maxAge,
                decoration: const InputDecoration(
                  labelText: 'Edad hasta',
                  helperText: 'Vacío: hasta la edad máxima de la prueba',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _min,
                decoration: const InputDecoration(
                  labelText: 'Desde (vacío = sin mínimo)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextFormField(
                controller: _max,
                decoration: const InputDecoration(
                  labelText: 'Hasta (vacío = sin máximo)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextFormField(
                controller: _points,
                decoration: const InputDecoration(labelText: 'Puntos'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    _number(v) == null ? 'Introduce los puntos.' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Introduce marcas en ${widget.test.unit == 'seconds'
                    ? 'segundos'
                    : widget.test.unit == 'meters'
                    ? 'metros'
                    : 'repeticiones'}; resolución ${formatMark(widget.test.markStep)}.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final min = _min.text.trim().isEmpty ? null : _number(_min.text);
          final max = _max.text.trim().isEmpty ? null : _number(_max.text);
          if ((_min.text.trim().isNotEmpty && min == null) ||
              (_max.text.trim().isNotEmpty && max == null) ||
              (min == null && max == null) ||
              (min != null && max != null && min > max)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revisa los límites del tramo.')),
            );
            return;
          }
          final minAge = _minAge.text.trim().isEmpty
              ? widget.test.minAge
              : int.tryParse(_minAge.text.trim());
          final maxAge = _maxAge.text.trim().isEmpty
              ? widget.test.maxAge
              : int.tryParse(_maxAge.text.trim());
          if (minAge == null ||
              maxAge == null ||
              minAge < widget.test.minAge ||
              maxAge > widget.test.maxAge ||
              minAge > maxAge) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revisa el rango de edad.')),
            );
            return;
          }
          widget.onSubmit(
            AdminScoreBand(
              id: widget.existing?.id ?? '',
              category: _category,
              minMark: min,
              maxMark: max,
              points: _number(_points.text)!,
              minAge: minAge,
              maxAge: maxAge,
            ),
          );
        },
        child: Text(
          widget.saving
              ? 'Guardando…'
              : widget.existing == null
              ? 'Guardar tramo'
              : 'Guardar cambios',
        ),
      ),
    ],
  );
}
