import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

class TrainerAgendaClientPicker extends StatefulWidget {
  const TrainerAgendaClientPicker({
    super.key,
    required this.repository,
    this.selectedId,
  });
  final TrainerRepository repository;
  final String? selectedId;
  @override
  State<TrainerAgendaClientPicker> createState() =>
      _TrainerAgendaClientPickerState();
}

class _TrainerAgendaClientPickerState extends State<TrainerAgendaClientPicker> {
  List<TrainerClient> _items = [];
  TrainerClient? _selected;
  bool _busy = true, _more = false;
  String? _error;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
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
      final rows = await widget.repository.clients(
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _selected ??= _items
              .where((c) => c.personId == widget.selectedId)
              .firstOrNull;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EntrenaDialog(
    title: const Text('Elegir alumno para la pauta'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selecciona un alumno con servicio activo. Después revisarás la sesión y la fecha.',
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar entre los alumnos cargados',
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Reintentar')),
        if (!_busy && _error == null && _items.isEmpty)
          const Text('No tienes alumnos activos. Invítalos desde Alumnos.'),
        RadioGroup<String>(
          groupValue: _selected?.personId,
          onChanged: (id) {
            if (!_busy) {
              setState(
                () => _selected = _items
                    .where((c) => c.personId == id)
                    .firstOrNull,
              );
            }
          },
          child: Column(
            children: [
              for (final c in _items.where(
                (c) =>
                    c.activeRelationId != null &&
                    c.name.toLowerCase().contains(_search.toLowerCase()),
              ))
                RadioListTile<String>(
                  value: c.personId,
                  title: Text(c.name),
                  enabled: !_busy,
                ),
            ],
          ),
        ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más alumnos'),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy || _selected == null || _error != null
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('Revisar pauta'),
      ),
    ],
  );
}
