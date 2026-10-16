import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Cierra también el teclado nativo de iOS al abandonar un campo o un diálogo.
void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
}
