import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_scoring_editor.dart';
import 'package:flutter/material.dart';

class AdminTestPassStandardsPage extends StatefulWidget {
  const AdminTestPassStandardsPage({
    super.key,
    required this.test,
    required this.repository,
    required this.editable,
  });

  final AdminProgramTest test;
  final AdminProgramRepository repository;
  final bool editable;

  @override
  State<AdminTestPassStandardsPage> createState() =>
      _AdminTestPassStandardsPageState();
}

class _AdminTestPassStandardsPageState
    extends State<AdminTestPassStandardsPage> {
  late Future<List<AdminPassStandard>> _standards = widget.repository
      .listPassStandards(widget.test.id);
  bool _saving = false;

  void _reload() => setState(() {
    _standards = widget.repository.listPassStandards(widget.test.id);
    _standards.ignore();
  });

  Future<void> _edit([AdminPassStandard? current]) async {
    final value = await showDialog<AdminPassStandard>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RetainedSaveDialog<AdminPassStandard>(
        save: (value) =>
            widget.repository.savePassStandard(widget.test.id, value),
        errorMessage: 'No se pudo guardar. Comprueba la marca y que las edades no se solapen. Tus datos se conservan.',
        builder: (_, submit, saving, error, markDirty) => _StandardDialog(
          test: widget.test,
          current: current,
          onSubmit: submit,
          saving: saving,
          error: error,
          onDirtyChanged: markDirty,
        ),
      ),
    );
    if (value == null || !mounted) return;
    _reload();
  }

  Future<void> _delete(AdminPassStandard standard) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar mínimo'),
        content: Text(
          '¿Borrar el mínimo para ${categoryLabel(standard.category)}, ${standard.minAge}–${standard.maxAge} años?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deletePassStandard(standard.id);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo borrar el mínimo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Mínimos · ${widget.test.name}')),
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
              '${categoryLabel(widget.test.category)} · edades ${widget.test.minAge}–${widget.test.maxAge} · ${widget.test.betterDirection == 'higher' ? 'se supera alcanzando o superando el mínimo' : 'se supera igualando o bajando del máximo'}',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Marcas para ser apto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.editable)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir mínimo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<AdminPassStandard>>(
              future: _standards,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: _reload,
                    child: const Text('No se pudieron cargar. Reintentar'),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Todavía no hay mínimos. Añade uno para cada columna y edad aplicable.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final standard in snapshot.data!)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${categoryLabel(standard.category)} · ${standard.minAge}–${standard.maxAge} años',
                          ),
                          subtitle: Text(
                            '${widget.test.betterDirection == 'higher' ? 'Al menos' : 'Como máximo'} ${formatMark(standard.threshold)} ${_unit(widget.test.unit)}',
                          ),
                          trailing: widget.editable
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar mínimo',
                                      onPressed: _saving
                                          ? null
                                          : () => _edit(standard),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Borrar mínimo',
                                      onPressed: _saving
                                          ? null
                                          : () => _delete(standard),
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

String _unit(String unit) => switch (unit) {
  'seconds' => 'segundos',
  'meters' => 'metros',
  _ => 'repeticiones',
};

class _StandardDialog extends StatefulWidget {
  const _StandardDialog({
    required this.test,
    this.current,
    required this.onSubmit,
    required this.saving,
    required this.error,
    required this.onDirtyChanged,
  });
  final ValueChanged<AdminPassStandard> onSubmit;
  final ValueChanged<bool> onDirtyChanged;
  final bool saving;
  final String? error;

  final AdminProgramTest test;
  final AdminPassStandard? current;
  @override
  State<_StandardDialog> createState() => _StandardDialogState();
}

class _StandardDialogState extends State<_StandardDialog> {
  final _form = GlobalKey<FormState>();
  late final _from = TextEditingController(
    text: (widget.current?.minAge ?? widget.test.minAge).toString(),
  );
  late final _to = TextEditingController(
    text: (widget.current?.maxAge ?? widget.test.maxAge).toString(),
  );
  late final _threshold = TextEditingController(
    text: widget.current == null ? '' : formatMark(widget.current!.threshold),
  );
  late String _category =
      widget.current?.category ??
      (widget.test.category == 'women' ? 'women' : 'men');

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _threshold.dispose();
    super.dispose();
  }

  late final String _initialSnapshot;
  String get _snapshot =>
      jsonEncode([_from.text, _to.text, _threshold.text, _category]);
  void _markDirty() => widget.onDirtyChanged(_snapshot != _initialSnapshot);
  void _change(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.current == null ? 'Añadir mínimo' : 'Editar mínimo'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _form,
        onChanged: _markDirty,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Columna del baremo',
              ),
              items: [
                if (widget.test.category != 'women')
                  const DropdownMenuItem(value: 'men', child: Text('Hombres')),
                if (widget.test.category != 'men')
                  const DropdownMenuItem(
                    value: 'women',
                    child: Text('Mujeres'),
                  ),
              ],
              onChanged: (value) =>
                  _change(() => _category = value ?? _category),
            ),
            TextFormField(
              controller: _from,
              decoration: const InputDecoration(labelText: 'Edad desde'),
              keyboardType: TextInputType.number,
              validator: _ageValidator,
            ),
            TextFormField(
              controller: _to,
              decoration: const InputDecoration(labelText: 'Edad hasta'),
              keyboardType: TextInputType.number,
              validator: _ageValidator,
            ),
            TextFormField(
              controller: _threshold,
              decoration: InputDecoration(
                labelText: widget.test.betterDirection == 'higher'
                    ? 'Marca mínima para aprobar'
                    : 'Marca máxima para aprobar',
                suffixText: _unit(widget.test.unit),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final mark = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return mark == null || !mark.isFinite || mark < 0
                    ? 'Introduce una marca válida.'
                    : null;
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
          if (!_form.currentState!.validate()) return;
          final from = int.parse(_from.text), to = int.parse(_to.text);
          if (from < widget.test.minAge ||
              to > widget.test.maxAge ||
              from > to) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Las edades deben quedar dentro de la prueba.'),
              ),
            );
            return;
          }
          widget.onSubmit(
            AdminPassStandard(
              id: widget.current?.id ?? '',
              category: _category,
              minAge: from,
              maxAge: to,
              threshold: double.parse(_threshold.text.replaceAll(',', '.')),
            ),
          );
        },
        child: Text(widget.saving ? 'Guardando…' : 'Guardar mínimo'),
      ),
    ],
  );

  String? _ageValidator(String? raw) {
    final value = int.tryParse(raw ?? '');
    return value == null || value < 0 || value > 120
        ? 'Edad entre 0 y 120.'
        : null;
  }
}
