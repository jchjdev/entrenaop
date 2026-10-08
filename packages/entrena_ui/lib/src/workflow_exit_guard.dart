import 'package:flutter/material.dart';

/// Vive en el router de cada aplicación. Cada pantalla registra su salida real;
/// no se guardan widgets ni borradores en una instancia global de dominio.
class WorkflowExitRegistry {
  final _controllers = <LocalKey, WorkflowExitController>{};
  WorkflowExitController controller(LocalKey key) =>
      _controllers.putIfAbsent(key, WorkflowExitController.new);
  Future<bool> requestExit(LocalKey key) async {
    final controller = _controllers[key];
    final allowed = await (controller?.onExit?.call() ?? Future.value(true));
    if (allowed) _controllers.remove(key);
    return allowed;
  }
}

class WorkflowExitController {
  Future<bool> Function()? onExit;
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
    this.saveDraftBeforeExit,
    this.confirmExit,
    this.title = '¿Salir sin guardar?',
    this.message = 'Se perderán los cambios que no hayas guardado en esta pantalla. Los datos ya guardados se conservan.',
    this.exitLabel = 'Salir sin guardar',
    super.key,
  });
  final bool Function() hasUnsavedChanges;
  final bool Function()? isBusy;
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
          builder: (dialogContext) => AlertDialog(
            title: Text(widget.title),
            content: Text(widget.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Seguir aquí'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(widget.exitLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
