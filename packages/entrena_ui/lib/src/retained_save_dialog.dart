import 'package:flutter/material.dart';

import 'entrena_dialog_actions.dart';

/// Una revisión previa cancelada conserva el formulario sin simular un fallo.
class RetainedSaveCancelled implements Exception {
  const RetainedSaveCancelled();
}

/// Conserva el formulario montado hasta que el callback confirme persistencia.
/// No conoce repositorios ni confunde un fallo de recarga con fallo de guardado.
class RetainedSaveDialog<T> extends StatefulWidget {
  const RetainedSaveDialog({
    required this.save,
    required this.builder,
    required this.errorMessage,
    super.key,
  });

  final Future<void> Function(T) save;
  final String errorMessage;
  final Widget Function(
    BuildContext,
    ValueChanged<T>,
    bool,
    String?,
    ValueChanged<bool>,
  )
  builder;

  @override
  State<RetainedSaveDialog<T>> createState() => _RetainedSaveDialogState<T>();
}

class _RetainedSaveDialogState<T> extends State<RetainedSaveDialog<T>> {
  bool _saving = false, _dirty = false, _leaving = false;
  bool _confirming = false;
  String? _error;

  Future<void> _submit(T value) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(value);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _leaving = true;
      });
      // PopScope debe reconstruirse antes de cerrar tras un guardado correcto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(value);
        }
      });
    } on RetainedSaveCancelled {
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.errorMessage;
        });
      }
    }
  }

  Future<void> _confirmExit() async {
    if (_saving || _leaving || _confirming) return;
    _confirming = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => EntrenaDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'Los cambios de este formulario se perderán. Lo que ya estaba guardado se conserva.',
        ),
        actions: [
          EntrenaDialogActions(
            primaryLabel: 'Continuar editando',
            onPrimary: () => Navigator.pop(context, false),
            secondary: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: EntrenaButtonStyles.destructive(context),
                child: const Text(
                  'Salir sin guardar',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    _confirming = false;
    if (leave != true || !mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<T>(
    canPop: _leaving || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _confirmExit();
    },
    child: ExcludeFocus(
      excluding: _saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: widget.builder(
          context,
          (value) {
            _submit(value);
          },
          _saving,
          _error,
          (dirty) {
            if (_dirty != dirty) setState(() => _dirty = dirty);
          },
        ),
      ),
    ),
  );
}
