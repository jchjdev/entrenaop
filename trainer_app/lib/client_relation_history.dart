import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

class ClientRelationHistory extends StatefulWidget {
  const ClientRelationHistory({
    super.key,
    required this.repository,
    required this.client,
  });
  final TrainerRepository repository;
  final TrainerClient client;
  @override
  State<ClientRelationHistory> createState() => _ClientRelationHistoryState();
}

class _ClientRelationHistoryState extends State<ClientRelationHistory> {
  final List<TrainerRelation> _items = [];
  bool _busy = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await widget.repository.clientRelations(
        widget.client.personId,
        before: _items.lastOrNull,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _more = items.length == 50;
      });
    } catch (error) {
      if (mounted) setState(() => _error = trainerError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Historial del vínculo · ${widget.client.name}'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consulta las fechas de alta y baja de cada etapa del servicio con este alumno.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${trainerDate(item.acceptedAt)} → ${item.endedAt == null ? 'En activo' : trainerDate(item.endedAt!)}',
                ),
              ),
            if ((_more || _error != null) && !_busy)
              TextButton(
                onPressed: _load,
                child: Text(_error != null ? 'Reintentar' : 'Más etapas'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
