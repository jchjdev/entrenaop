import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import 'trainer_month_calendar.dart';

class TrainerAgendaColors extends ChangeNotifier {
  TrainerAgendaColors(this._client, this._owner);

  final SupabaseClient _client;
  final String _owner;
  Map<String, TrainerAgendaColor> _colors = const {};
  Future<void>? _refreshing;
  int _writes = 0;

  TrainerAgendaColor? operator [](String id) => _colors[id];

  Future<void> refresh() => _refreshing ??= _read().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _read() async {
    final writes = _writes;
    final response = await authenticatedTrainerRpc(
      _client,
      _owner,
      'list_trainer_agenda_colors',
    ) as Map;
    if (writes != _writes) return;
    final palette = TrainerAgendaColor.values.asNameMap();
    _colors = {
      for (final entry in response.entries)
        entry.key as String: ?palette[entry.value],
    };
    notifyListeners();
  }

  Future<void> save(String clientId, TrainerAgendaColor? color) async {
    await authenticatedTrainerRpc(
      _client,
      _owner,
      'set_trainer_agenda_color',
      params: {'p_client_id': clientId, 'p_color': color?.name},
    );
    _writes++;
    if (color == null) {
      _colors = {..._colors}..remove(clientId);
    } else {
      _colors = {..._colors, clientId: color};
    }
    notifyListeners();
  }
}

class TrainerAgendaColorPicker extends StatefulWidget {
  const TrainerAgendaColorPicker({
    super.key,
    required this.colors,
    required this.clientId,
  });

  final TrainerAgendaColors colors;
  final String clientId;

  @override
  State<TrainerAgendaColorPicker> createState() =>
      _TrainerAgendaColorPickerState();
}

class _TrainerAgendaColorPickerState extends State<TrainerAgendaColorPicker> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // El color automático sigue disponible si falla esta carga inicial.
    widget.colors.refresh().catchError((Object _) {});
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    final colors = widget.colors;
    final clientId = widget.clientId;
    try {
      await colors.refresh();
      if (!mounted || widget.clientId != clientId) return;
      final current = colors[clientId];
      var selected = current;
      final result = await showDialog<({TrainerAgendaColor? color})>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Color en agenda'),
            scrollable: true,
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in [null, ...TrainerAgendaColor.values])
                  ChoiceChip(
                    avatar: Icon(
                      Icons.circle,
                      size: 16,
                      color: trainerCalendarDisplayColor(
                        context,
                        clientId,
                        color,
                      ),
                    ),
                    label: Text(color?.label ?? 'Automático'),
                    selected: selected == color,
                    onSelected: (_) => update(() => selected = color),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, (color: selected)),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
      if (!mounted ||
          widget.clientId != clientId ||
          result == null ||
          result.color == current) {
        return;
      }
      await colors.save(clientId, result.color);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar el color de la agenda. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.colors,
    builder: (context, _) => ActionChip(
      avatar: Icon(
        Icons.circle,
        size: 16,
        color: trainerCalendarDisplayColor(
          context,
          widget.clientId,
          widget.colors[widget.clientId],
        ),
      ),
      label: const Text('Color en agenda'),
      onPressed: _busy ? null : _open,
    ),
  );
}
