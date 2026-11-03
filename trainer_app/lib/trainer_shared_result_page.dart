import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';

/// Lectura con permiso propio: no usa el repositorio de edición del autor.
class TrainerSharedResultPage extends StatefulWidget {
  const TrainerSharedResultPage({
    super.key,
    required this.repository,
    required this.clientId,
    required this.scheduledId,
    this.isSelf = false,
  });
  final TrainerSharedWorkoutResultRepository repository;
  final String clientId, scheduledId;
  final bool isSelf;

  @override
  State<TrainerSharedResultPage> createState() =>
      _TrainerSharedResultPageState();
}

class _TrainerSharedResultPageState extends State<TrainerSharedResultPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _result;
  bool _busy = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrainerSharedResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.clientId != widget.clientId ||
        oldWidget.scheduledId != widget.scheduledId) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    // No conservar una respuesta anterior mientras se revalidan permisos,
    // cambia la identidad o se abre el resultado de otro alumno.
    setState(() {
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final result = await widget.repository.result(
        widget.clientId,
        widget.scheduledId,
      );
      if (!mounted || request != _request) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = 'No se puede consultar el resultado. Actualiza para comprobar la conexión y los permisos.',
      );
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isSelf ? 'Tu resultado' : 'Resultado compartido'),
      actions: [
        IconButton(
          tooltip: 'Actualizar resultado',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _result != null
        ? TrainerWorkoutResultContent(
            result: _result!,
            header: Text(
              widget.isSelf
                  ? 'Solo lectura · Tus resultados deportivos. La pauta original se conserva.'
                  : 'Solo lectura · Resultados deportivos autorizados por el alumno. Las notas y conversaciones siguen siendo privadas.',
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ??
                        'Esta sesión todavía no tiene un resultado completado.',
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Actualizar')),
                ],
              ),
            ),
          ),
  );
}
