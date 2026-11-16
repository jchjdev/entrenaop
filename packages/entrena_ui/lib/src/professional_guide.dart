import 'package:flutter/material.dart';

import 'professional_guide_storage_stub.dart'
    if (dart.library.js_interop) 'professional_guide_storage_web.dart'
    as storage;

class ProfessionalGuideStep {
  const ProfessionalGuideStep({
    required this.title,
    required this.text,
    required this.destination,
    required this.path,
    required this.icon,
  });

  final String title, text, destination, path;
  final IconData icon;
}

/// La preferencia pertenece a esta cuenta y este panel en el navegador.
class ProfessionalGuideController {
  ProfessionalGuideController({
    required String panel,
    required String accountId,
    bool Function(String) read = storage.readHiddenGuide,
    this._write = storage.writeHiddenGuide,
  }) : _key = 'entrenaop.guide.v1.$panel.$accountId' {
    try {
      hidden = read(_key);
    } catch (_) {
      // La guía sigue accesible si el navegador bloquea el almacenamiento.
    }
  }

  final String _key;
  final void Function(String, bool) _write;
  bool hidden = false;
  bool _offered = false;

  void _setHidden(bool value) {
    if (hidden == value) return;
    hidden = value;
    try {
      _write(_key, value);
    } catch (_) {
      // Conserva la elección durante la visita.
    }
  }
}

class ProfessionalGuideHost extends StatefulWidget {
  const ProfessionalGuideHost({
    super.key,
    required this.controller,
    required this.offerOnEntry,
    required this.steps,
    required this.onNavigate,
    required this.child,
  });

  final ProfessionalGuideController controller;
  final bool offerOnEntry;
  final List<ProfessionalGuideStep> steps;
  final ValueChanged<String> onNavigate;
  final Widget child;

  static VoidCallback? openerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GuideScope>()?.open;

  @override
  State<ProfessionalGuideHost> createState() => _ProfessionalGuideHostState();
}

class _ProfessionalGuideHostState extends State<ProfessionalGuideHost> {
  bool _open = false;

  void _offer() {
    final controller = widget.controller;
    if (!widget.offerOnEntry ||
        widget.steps.isEmpty ||
        controller.hidden ||
        controller._offered) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller != controller ||
          !widget.offerOnEntry ||
          widget.steps.isEmpty ||
          controller.hidden ||
          controller._offered ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _show(welcome: true);
    });
  }

  Future<void> _show({bool welcome = false}) async {
    if (_open || widget.steps.isEmpty) return;
    final controller = widget.controller;
    controller._offered = true;
    _open = true;
    try {
      final path = await showDialog<String>(
        context: context,
        builder: (_) => _GuideDialog(
          welcome: welcome,
          steps: widget.steps,
          controller: controller,
        ),
      );
      if (mounted && widget.controller == controller && path != null) {
        widget.onNavigate(path);
      }
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _offer();
    return _GuideScope(
      open: widget.steps.isEmpty ? null : () => _show(),
      child: widget.child,
    );
  }
}

class _GuideScope extends InheritedWidget {
  const _GuideScope({required this.open, required super.child});
  final VoidCallback? open;

  @override
  bool updateShouldNotify(_GuideScope oldWidget) =>
      (open == null) != (oldWidget.open == null);
}

class ProfessionalGuideButton extends StatelessWidget {
  const ProfessionalGuideButton({super.key, this.navigation = false});

  final bool navigation;

  @override
  Widget build(BuildContext context) {
    final open = ProfessionalGuideHost.openerOf(context);
    if (open == null) return const SizedBox.shrink();
    const icon = Icon(Icons.help_outline);
    const label = Text('Guía de uso');
    if (navigation) {
      return ListTile(
        dense: true,
        leading: icon,
        title: label,
        onTap: () {
          Scaffold.maybeOf(context)?.closeDrawer();
          open();
        },
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(onPressed: open, icon: icon, label: label),
    );
  }
}

class _GuideDialog extends StatefulWidget {
  const _GuideDialog({
    required this.welcome,
    required this.steps,
    required this.controller,
  });

  final bool welcome;
  final List<ProfessionalGuideStep> steps;
  final ProfessionalGuideController controller;

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  late bool _welcome = widget.welcome;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;
    return AlertDialog(
      scrollable: true,
      title: Text(_welcome ? 'Guía de uso' : step.title),
      content: SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_welcome)
              const Text('Un vistazo rápido a las opciones del panel.')
            else ...[
              Text('Paso ${_index + 1} de ${widget.steps.length}'),
              const SizedBox(height: 12),
              Text(step.text),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, step.path),
                icon: Icon(step.icon),
                label: Text('Ir a ${step.destination}'),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('No volver a mostrar al entrar'),
              value: widget.controller.hidden,
              onChanged: (value) => setState(() {
                widget.controller._setHidden(value == true);
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_welcome ? 'Ahora no' : 'Cerrar'),
        ),
        if (!_welcome && _index > 0)
          TextButton(
            onPressed: () => setState(() => _index--),
            child: const Text('Anterior'),
          ),
        FilledButton(
          onPressed: () {
            if (_welcome) {
              setState(() => _welcome = false);
            } else if (last) {
              Navigator.pop(context);
            } else {
              setState(() => _index++);
            }
          },
          child: Text(
            _welcome
                ? 'Ver guía'
                : last
                ? 'Terminar'
                : 'Siguiente',
          ),
        ),
      ],
    );
  }
}
