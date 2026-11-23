import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/directory/domain.dart';

class AdminSpecialtySuggestions extends StatefulWidget {
  const AdminSpecialtySuggestions({super.key, required this.repository});
  final DirectorySpecialtyReview repository;

  @override
  State<AdminSpecialtySuggestions> createState() =>
      _AdminSpecialtySuggestionsState();
}

class _AdminSpecialtySuggestionsState extends State<AdminSpecialtySuggestions> {
  late var _pending = widget.repository.pendingSpecialtySuggestions();
  bool _opening = false;

  void _reload() => setState(
    () => _pending = widget.repository.pendingSpecialtySuggestions(),
  );

  Future<void> _review(DirectorySpecialtySuggestion suggestion) async {
    setState(() => _opening = true);
    try {
      final catalog = await widget.repository.specialtyCatalog();
      if (!mounted) return;
      final saved = await showDialog<_Review>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RetainedSaveDialog<_Review>(
          save: (value) => widget.repository.reviewSpecialtySuggestion(
            suggestion.id,
            approve: value.decision != _Decision.decline,
            existingId: value.existingId,
            name: value.name,
            note: value.note,
          ),
          errorMessage: 'No se pudo guardar. Si el nombre ya está en uso, vincula la sugerencia a la especialidad existente.',
          builder: (context, submit, saving, error, markDirty) => _ReviewDialog(
            suggestion: suggestion,
            catalog: catalog,
            submit: submit,
            saving: saving,
            error: error,
            markDirty: markDirty,
          ),
        ),
      );
      if (saved != null && mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(directoryError(e))));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sugerencias de especialidades',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<DirectorySpecialtySuggestion>>(
            future: _pending,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: _reload,
                  child: const Text('No se pudieron cargar. Reintentar'),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const Text('No hay sugerencias pendientes.');
              }
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        [
                          item.proposer ?? 'Preparador',
                          if (item.details.isNotEmpty) item.details,
                        ].join('\n'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _opening ? null : () => _review(item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

enum _Decision { create, link, decline }

typedef _Review = ({
  _Decision decision,
  String? name,
  String? existingId,
  String note,
});

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.suggestion,
    required this.catalog,
    required this.submit,
    required this.saving,
    this.error,
    required this.markDirty,
  });

  final DirectorySpecialtySuggestion suggestion;
  final List<DirectorySpecialty> catalog;
  final ValueChanged<_Review> submit;
  final bool saving;
  final String? error;
  final ValueChanged<bool> markDirty;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.suggestion.name);
  final _note = TextEditingController();
  _Decision _decision = _Decision.create;
  String? _existingId;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Revisar ${widget.suggestion.name}'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        onChanged: () => widget.markDirty(true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.suggestion.details.isNotEmpty) ...[
              Text(widget.suggestion.details),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<_Decision>(
              initialValue: _decision,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Decisión'),
              items: const [
                DropdownMenuItem(
                  value: _Decision.create,
                  child: Text('Aprobar y añadir al catálogo'),
                ),
                DropdownMenuItem(
                  value: _Decision.link,
                  child: Text('Vincular a una especialidad existente'),
                ),
                DropdownMenuItem(
                  value: _Decision.decline,
                  child: Text('Rechazar'),
                ),
              ],
              onChanged: (decision) => setState(() => _decision = decision!),
            ),
            const SizedBox(height: 12),
            if (_decision == _Decision.create)
              TextFormField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nombre en el catálogo',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Escribe un nombre.'
                    : null,
              ),
            if (_decision == _Decision.link)
              DropdownButtonFormField<String>(
                initialValue: _existingId,
                decoration: const InputDecoration(
                  labelText: 'Especialidad existente',
                ),
                isExpanded: true,
                items: [
                  for (final item in widget.catalog)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (id) => _existingId = id,
                validator: (value) =>
                    value == null ? 'Elige una especialidad.' : null,
              ),
            TextFormField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _decision == _Decision.decline
                    ? 'Motivo para el entrenador'
                    : 'Nota para el entrenador (opcional)',
              ),
              validator: (value) =>
                  _decision == _Decision.decline &&
                      (value?.trim().isEmpty ?? true)
                  ? 'Explica brevemente el motivo.'
                  : null,
            ),
            if (widget.error != null) Text(widget.error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: widget.saving
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                widget.submit((
                  decision: _decision,
                  name: _decision == _Decision.create
                      ? _name.text.trim()
                      : null,
                  existingId: _decision == _Decision.link ? _existingId : null,
                  note: _note.text.trim(),
                ));
              },
        child: const Text('Confirmar decisión'),
      ),
    ],
  );
}
