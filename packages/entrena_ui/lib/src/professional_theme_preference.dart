import 'package:flutter/material.dart';

import 'professional_theme_storage.dart' as storage;

/// Preferencia visual del navegador. No forma parte de la identidad ni permisos.
class ProfessionalThemeController extends ValueNotifier<ThemeMode> {
  ProfessionalThemeController({
    String? Function()? read,
    void Function(String)? write,
  }) : _write = write ?? storage.writeProfessionalTheme,
       super(_load(read ?? storage.readProfessionalTheme));

  final void Function(String) _write;

  static ThemeMode _load(String? Function() read) {
    try {
      return read() == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  void toggle() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    try {
      _write(value.name);
    } catch (_) {
      // Un navegador sin almacenamiento permite cambiarlo durante esta visita.
    }
  }
}

class ProfessionalThemeScope
    extends InheritedNotifier<ProfessionalThemeController> {
  const ProfessionalThemeScope({
    super.key,
    required ProfessionalThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ProfessionalThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ProfessionalThemeScope>()
      ?.notifier;
}

class ProfessionalThemeButton extends StatelessWidget {
  const ProfessionalThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ProfessionalThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final light = controller.value == ThemeMode.light;
    return IconButton(
      key: const ValueKey('professional-theme-toggle'),
      tooltip: light ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro',
      onPressed: controller.toggle,
      icon: Icon(light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
    );
  }
}
