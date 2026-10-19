import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Misma salida del teclado en páginas, diálogos y paneles de ambas apps.
/// Se instala por encima del Navigator para incluir también sus overlays.
class EntrenaInputPolicy extends StatefulWidget {
  const EntrenaInputPolicy({super.key, required this.child});

  final Widget child;

  @override
  State<EntrenaInputPolicy> createState() => _EntrenaInputPolicyState();
}

class _EntrenaInputPolicyState extends State<EntrenaInputPolicy> {
  bool _wasEditing = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editing =
        focusContext?.findAncestorStateOfType<EditableTextState>() != null;
    // Pasar entre campos conserva el teclado; salir de la edición también
    // retira el teclado nativo que iOS puede conservar tras perder el foco.
    if (_wasEditing && !editing) _hideKeyboard();
    _wasEditing = editing;
  }

  void _hideKeyboard() {
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    ),
    child: Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                _hideKeyboard();
                return null;
              },
            ),
      },
      child: widget.child,
    ),
  );
}
