import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

typedef AssignmentClient = ({String id, String relationId, String name});

/// Selección dentro de la confirmación; nunca crea ni reactiva un vínculo.
class TrainerAssignmentClientField extends StatefulWidget {
  const TrainerAssignmentClientField({
    super.key,
    required this.repository,
    required this.onChanged,
    this.initialClientId,
    this.enabled = true,
  });
  final TrainerRepository repository;
  final String? initialClientId;
  final bool enabled;
  final ValueChanged<AssignmentClient?> onChanged;

  @override
  State<TrainerAssignmentClientField> createState() =>
      _TrainerAssignmentClientFieldState();
}

class _TrainerAssignmentClientFieldState
    extends State<TrainerAssignmentClientField> {
  final _options = <String, AssignmentClient>{};
  TrainerClient? _cursor;
  String? _selected, _error;
  String _query = '';
  bool _busy = true, _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_options.isNotEmpty) widget.onChanged(null);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.repository.access();
      if (!access.effective) {
        throw const FormatException(
          'El acceso profesional no permite nuevas asignaciones.',
        );
      }
      // La agenda puede estar filtrada por un alumno fuera de la primera página
      // o por «Para mí». Se verifica su vínculo, sin elegir a otra persona.
      AssignmentClient? initial;
      if (!more && widget.initialClientId != null) {
        final relations = await widget.repository.clientRelations(
          widget.initialClientId!,
        );
        final active = relations.where((r) => r.endedAt == null).firstOrNull;
        if (active == null) {
          throw const FormatException(
            'El alumno seleccionado ya no tiene un servicio activo. Actualiza la agenda.',
          );
        }
        initial = (
          id: active.personId,
          relationId: active.id,
          name: active.name,
        );
      }
      final rows = await widget.repository.clients(
        before: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _options.clear();
        for (final c in rows.where((c) => c.activeRelationId != null)) {
          _options[c.personId] = (
            id: c.personId,
            relationId: c.activeRelationId!,
            name: c.isSelf ? '${c.name} · Para mí' : c.name,
          );
        }
        if (initial != null) {
          _options[initial.id] = initial;
          _selected = initial.id;
        }
        if (!_options.containsKey(_selected)) _selected = null;
        _cursor = rows.lastOrNull;
        _more = rows.length == 50;
      });
      widget.onChanged(_options[_selected]);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : trainerError(e),
        );
        widget.onChanged(null);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options.values.where(
      (c) =>
          c.id == _selected ||
          c.name.toLowerCase().contains(_query.toLowerCase()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_options.length > 8)
          TextField(
            enabled: widget.enabled && !_busy,
            decoration: const InputDecoration(labelText: 'Buscar alumno'),
            onChanged: (value) => setState(() => _query = value),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('assignment-client-${_selected ?? "none"}'),
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Alumno'),
          hint: const Text('Elige a quién asignar la sesión'),
          items: [
            for (final c in options)
              DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: !widget.enabled || _busy || _error != null
              ? null
              : (id) {
                  setState(() => _selected = id);
                  widget.onChanged(_options[id]);
                },
        ),
        if (_more)
          TextButton(
            onPressed: widget.enabled && !_busy
                ? () => _load(more: true)
                : null,
            child: const Text('Cargar más alumnos'),
          ),
        if (!_busy && _options.isEmpty && _error == null)
          const Text('No tienes alumnos activos. Invítalos desde Alumnos.'),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: widget.enabled && !_busy ? _load : null,
            child: const Text('Reintentar alumnos'),
          ),
        ],
      ],
    );
  }
}
