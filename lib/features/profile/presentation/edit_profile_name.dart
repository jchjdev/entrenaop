import 'package:flutter/material.dart';

import '../data/profile_name_repository.dart';

/// El borrador y su error permanecen abiertos hasta confirmar el guardado.
Future<String?> editProfileName(
  BuildContext context, {
  required String current,
  required Future<String> Function(String) save,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _NameDialog(current: current, save: save),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current, required this.save});
  final String current;
  final Future<String> Function(String) save;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.current);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = validateProfileName(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final value = await widget.save(_name.text);
      if (mounted) Navigator.pop(context, value);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FormatException ? e.message : 'No se pudo confirmar el nombre. Conservamos lo escrito; puedes reintentar.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Cambiar nombre'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Nombre',
                errorText: _error,
                errorMaxLines: 4,
              ),
              onSubmitted: (_) => _save(),
            ),
            const Text('Así aparecerás en EntrenaOP y ante tus preparadores.'),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar nombre'),
        ),
      ],
    ),
  );
}
