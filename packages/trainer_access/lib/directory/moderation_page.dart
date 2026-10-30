import 'package:flutter/material.dart';

import 'domain.dart';
import 'presentation.dart';

class DirectoryModerationPage extends StatefulWidget {
  const DirectoryModerationPage({
    super.key,
    required this.repository,
    required this.loadPhoto,
  });
  final DirectoryRepository repository;
  final DirectoryPhotoLoader loadPhoto;
  @override
  State<DirectoryModerationPage> createState() =>
      _DirectoryModerationPageState();
}

class _DirectoryModerationPageState extends State<DirectoryModerationPage> {
  List<DirectoryReport> _items = [];
  bool _busy = false;
  String? _error, _after;
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
      final items = await widget.repository.reports(
        after: more ? _after : null,
      );
      if (mounted) {
        setState(() {
          _items = [if (more) ..._items, ...items];
          _after = items.length == 50 ? items.last.id : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(DirectoryReport r, bool suspend) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          suspend
              ? 'Suspender ficha'
              : r.suspended
              ? 'Restablecer ficha'
              : 'Descartar denuncia',
        ),
        content: TextField(
          controller: reason,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo de la decisión (mínimo 5 caracteres)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    if (text.length < 5) {
      setState(
        () => _error = 'Explica el motivo con al menos cinco caracteres.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.moderate(r.id, suspend: suspend, reason: text);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = directoryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Denuncias del directorio')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Las denuncias no ocultan perfiles automáticamente. Restablecer una ficha no concede derechos de publicación ni cambia su plan.',
            ),
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: const Text('Actualizar'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (!_busy && _error == null && _items.isEmpty)
              const Text('No hay denuncias.'),
            for (final r in _items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DirectoryPhoto(
                        path: r.profile.photoPath,
                        load: widget.loadPhoto,
                      ),
                      Text(
                        r.profile.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(r.profile.description),
                      Text('Motivo: ${r.reason} · Estado: ${r.status}'),
                      Text(r.details),
                      Text(
                        r.suspended
                            ? 'Ficha suspendida'
                            : 'Sin suspensión de moderación',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy ? null : () => _resolve(r, true),
                            child: Text(
                              r.suspended
                                  ? 'Mantener suspensión'
                                  : 'Suspender ficha',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : () => _resolve(r, false),
                            child: Text(
                              r.suspended
                                  ? 'Restablecer ficha'
                                  : 'Descartar denuncia',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_after != null)
              TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Ver más denuncias'),
              ),
          ],
        ),
      ),
    ),
  );
}
