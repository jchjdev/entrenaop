import 'package:flutter/material.dart';

import 'entrena_dialog_actions.dart';

/// Vive en el router de cada aplicación. Cada pantalla registra su salida real;
/// no se guardan widgets ni borradores en una instancia global de dominio.
class WorkflowExitRegistry {
  final _controllers = <LocalKey, WorkflowExitController>{};
  WorkflowExitController controller(LocalKey key) => _controllers.putIfAbsent(
    key,
    () => WorkflowExitController._(
      (controller) => _handlerChanged(key, controller),
    ),
  );

  void _handlerChanged(LocalKey key, WorkflowExitController controller) {
    if (controller.onExit != null) {
      _controllers.putIfAbsent(key, () => controller);
    } else if (identical(_controllers[key], controller)) {
      // El dispose de una vista antigua no puede retirar la guarda de su relevo.
      _controllers.remove(key);
    }
  }

  Future<bool> requestExit(LocalKey key) async {
    final controller = _controllers[key];
    final allowed = await (controller?.onExit?.call() ?? Future.value(true));
    // Salir de una rama puede conservar su pantalla y su borrador montados.
    // La guarda permanece hasta que la vista retire realmente su handler.
    if (allowed &&
        controller?.onExit == null &&
        identical(_controllers[key], controller)) {
      _controllers.remove(key);
    }
    return allowed;
  }
}

class WorkflowExitController {
  WorkflowExitController() : _onHandlerChanged = null;
  WorkflowExitController._(this._onHandlerChanged);

  final void Function(WorkflowExitController)? _onHandlerChanged;
  Future<bool> Function()? _onExit;

  Future<bool> Function()? get onExit => _onExit;
  set onExit(Future<bool> Function()? handler) {
    _onExit = handler;
    _onHandlerChanged?.call(this);
  }
}

class WorkflowExitScope extends InheritedWidget {
  const WorkflowExitScope({
    required this.controller,
    required super.child,
    super.key,
  });
  final WorkflowExitController controller;
  static WorkflowExitController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkflowExitScope>()
      ?.controller;
  @override
  bool updateShouldNotify(WorkflowExitScope oldWidget) =>
      controller != oldWidget.controller;
}

/// El router consulta este guard tanto en atrás como al navegar a otro destino.
/// Los getters leen el estado actual, incluidos campos que no reconstruyen UI.
class WorkflowDraftGuard extends StatefulWidget {
  const WorkflowDraftGuard({
    required this.hasUnsavedChanges,
    required this.child,
    this.isBusy,
    this.beforeExit,
    this.saveDraftBeforeExit,
    this.confirmExit,
    this.title = '¿Salir sin guardar?',
    this.message = 'Se perderán los cambios que no hayas guardado en esta pantalla. Los datos ya guardados se conservan.',
    this.exitLabel = 'Salir sin guardar',
    super.key,
  });
  final bool Function() hasUnsavedChanges;
  final bool Function()? isBusy;

  /// Protege un editor contenido antes de comprobar el borrador de la página.
  final Future<bool> Function()? beforeExit;
  final Future<bool> Function()? saveDraftBeforeExit;

  /// Un flujo con varias salidas puede decidir sin cambiar el guard del router
  /// ni el comportamiento predeterminado de los demás formularios.
  final Future<bool> Function(BuildContext context)? confirmExit;
  final String title, message, exitLabel;
  final Widget child;
  @override
  State<WorkflowDraftGuard> createState() => _WorkflowDraftGuardState();
}

class _WorkflowDraftGuardState extends State<WorkflowDraftGuard> {
  WorkflowExitController? _controller;
  Future<bool>? _pending;
  late final Future<bool> Function() _handler = _request;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = WorkflowExitScope.maybeOf(context);
    if (_controller?.onExit == _handler) _controller?.onExit = null;
    _controller = next;
    _controller?.onExit = _handler;
  }

  @override
  void dispose() {
    if (_controller?.onExit == _handler) _controller?.onExit = null;
    super.dispose();
  }

  Future<bool> _request() =>
      _pending ??= _confirm().whenComplete(() => _pending = null);
  Future<bool> _confirm() async {
    if (widget.isBusy?.call() == true) return false;
    if (widget.beforeExit != null && !await widget.beforeExit!()) return false;
    if (widget.saveDraftBeforeExit != null) {
      try {
        if (await widget.saveDraftBeforeExit!()) return true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hemos podido guardar el borrador. Sigue editando e inténtalo otra vez.',
              ),
            ),
          );
        }
        return false;
      }
    } else if (!widget.hasUnsavedChanges()) {
      return true;
    }
    if (!mounted) return false;
    if (widget.confirmExit case final confirmExit?) {
      return confirmExit(context);
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => EntrenaDialog(
            title: Text(widget.title),
            content: Text(widget.message),
            actions: [
              EntrenaDialogActions(
                primaryLabel: 'Continuar',
                onPrimary: () => Navigator.pop(dialogContext, false),
                secondary: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: EntrenaButtonStyles.destructive(dialogContext),
                    child: Text(widget.exitLabel, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
