import 'package:flutter/material.dart';
import 'package:workout_core/guided_program.dart';

import '../domain/admin_guided_repository.dart';

Future<GuidedProgramCategory?> editGuidedCategory(
  BuildContext context,
  AdminGuidedRepository repository, {
  GuidedProgramCategory? original,
}) => showDialog<GuidedProgramCategory>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CategoryEditor(repository: repository, original: original),
);

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.repository, this.original});
  final AdminGuidedRepository repository;
  final GuidedProgramCategory? original;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.original?.name ?? '');
  late bool _active = widget.original?.active ?? true;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _name.text.trim().length > 48) {
      setState(() => _error = 'Escribe un nombre de hasta 48 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final category = await widget.repository.saveCategory(
        _name.text.trim(),
        original: widget.original,
        active: _active,
      );
      if (mounted) Navigator.pop(context, category);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FormatException ? e.message : 'No se pudo guardar la categoría. Revisa la conexión y reintenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.original == null ? 'Crear categoría' : 'Editar categoría',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 48,
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
              ),
            ),
            if (widget.original != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible para nuevos programas'),
                subtitle: const Text(
                  'Desactivarla conserva los programas que ya la utilizan.',
                ),
                value: _active,
                onChanged: _busy ? null : (v) => setState(() => _active = v),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando…' : 'Guardar categoría'),
        ),
      ],
    ),
  );
}

Future<void> manageGuidedCategories(
  BuildContext context,
  AdminGuidedRepository repository,
) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
      child: _CategoryManager(repository: repository),
    ),
  ),
);

class _CategoryManager extends StatefulWidget {
  const _CategoryManager({required this.repository});
  final AdminGuidedRepository repository;
  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  late Future<List<GuidedProgramCategory>> _items;
  @override
  void initState() {
    super.initState();
    _items = widget.repository.categories();
  }

  Future<void> _edit([GuidedProgramCategory? original]) async {
    await editGuidedCategory(context, widget.repository, original: original);
    if (mounted) {
      setState(() {
        _items = widget.repository.categories();
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Categorías de programas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar categorías',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<GuidedProgramCategory>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(() {
                    _items = widget.repository.categories();
                  }),
                  child: const Text('Reintentar categorías'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final c in snapshot.data!)
                    ListTile(
                      title: Text(c.name),
                      subtitle: Text(c.active ? 'Disponible' : 'Desactivada'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(c),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.add),
            label: const Text('Crear categoría'),
          ),
        ],
      ),
    ),
  );
}
