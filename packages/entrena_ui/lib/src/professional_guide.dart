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
    this.topic = 'Primeros pasos',
  });

  final String title, text, destination, path, topic;
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
    this.currentPath,
  });

  final ProfessionalGuideController controller;
  final bool offerOnEntry;
  final List<ProfessionalGuideStep> steps;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final String? currentPath;

  static VoidCallback? openerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GuideScope>()?.open;

  @override
  State<ProfessionalGuideHost> createState() => _ProfessionalGuideHostState();
}

class _ProfessionalGuideHostState extends State<ProfessionalGuideHost> {
  bool _open = false;
  ProfessionalGuideStep? _active;

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

  Future<void> _show({
    bool welcome = false,
    int index = 0,
    bool showIndex = false,
  }) async {
    if (_open || widget.steps.isEmpty) return;
    final controller = widget.controller;
    controller._offered = true;
    _open = true;
    try {
      final steps = widget.steps;
      final step = await showDialog<ProfessionalGuideStep>(
        context: context,
        builder: (_) => _GuideDialog(
          welcome: welcome,
          steps: steps,
          controller: controller,
          initialIndex: index,
          showIndex: showIndex,
        ),
      );
      if (mounted &&
          widget.controller == controller &&
          step != null &&
          widget.steps.contains(step)) {
        _go(step);
      }
    } finally {
      _open = false;
    }
  }

  void _go(ProfessionalGuideStep step) {
    setState(() => _active = step);
    widget.onNavigate(step.path);
  }

  @override
  Widget build(BuildContext context) {
    _offer();
    final step = _active;
    final index = step == null ? -1 : widget.steps.indexOf(step);
    final active =
        index >= 0 && Uri.parse(step!.path).path == widget.currentPath;
    return _GuideScope(
      open: widget.steps.isEmpty ? null : () => _show(),
      step: active ? _active : null,
      next: active && index + 1 < widget.steps.length
          ? () => _go(widget.steps[index + 1])
          : null,
      index: active ? () => _show(index: index, showIndex: true) : null,
      close: () => setState(() => _active = null),
      child: widget.child,
    );
  }
}

class _GuideScope extends InheritedWidget {
  const _GuideScope({
    required this.open,
    required this.step,
    required this.next,
    required this.index,
    required this.close,
    required super.child,
  });
  final VoidCallback? open;
  final ProfessionalGuideStep? step;
  final VoidCallback? next, index;
  final VoidCallback close;

  @override
  bool updateShouldNotify(_GuideScope oldWidget) =>
      (open == null) != (oldWidget.open == null) || step != oldWidget.step;
}

/// Queda a la vista mientras el usuario está en la pantalla del paso.
class ProfessionalGuideProgress extends StatelessWidget {
  const ProfessionalGuideProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = context.dependOnInheritedWidgetOfExactType<_GuideScope>();
    final step = guide?.step;
    if (guide == null || step == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: theme.textTheme.titleSmall),
                  Text(step.text, style: theme.textTheme.bodySmall),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: guide.index,
                        child: const Text('Índice'),
                      ),
                      if (guide.next != null)
                        TextButton(
                          onPressed: guide.next,
                          child: const Text('Siguiente paso'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar recorrido',
              onPressed: guide.close,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
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
    required this.initialIndex,
    required this.showIndex,
  });

  final bool welcome;
  final List<ProfessionalGuideStep> steps;
  final ProfessionalGuideController controller;
  final int initialIndex;
  final bool showIndex;

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  late bool _welcome = widget.welcome;
  late int _index = widget.initialIndex;
  late bool _showIndex = widget.showIndex;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;
    final topics = widget.steps.map((step) => step.topic).toSet();
    return AlertDialog(
      scrollable: true,
      title: Text(_welcome || _showIndex ? 'Guía de uso' : step.title),
      content: SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_welcome)
              const Text(
                'Sigue el recorrido o abre en el índice la tarea que quieras hacer.',
              )
            else if (_showIndex) ...[
              for (final topic in topics) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    topic,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final (index, item) in widget.steps.indexed)
                  if (item.topic == topic)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() {
                        _index = index;
                        _showIndex = false;
                      }),
                    ),
              ],
            ] else ...[
              Text('Paso ${_index + 1} de ${widget.steps.length}'),
              const SizedBox(height: 12),
              Text(step.text),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, step),
                icon: Icon(step.icon),
                label: Text('Ir a ${step.destination}'),
              ),
            ],
            if (!_showIndex) ...[
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_welcome ? 'Ahora no' : 'Cerrar'),
        ),
        if (!_showIndex)
          TextButton(
            onPressed: () => setState(() {
              _welcome = false;
              _showIndex = true;
            }),
            child: const Text('Índice'),
          ),
        if (!_welcome && !_showIndex && _index > 0)
          TextButton(
            onPressed: () => setState(() => _index--),
            child: const Text('Anterior'),
          ),
        if (!_showIndex)
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
