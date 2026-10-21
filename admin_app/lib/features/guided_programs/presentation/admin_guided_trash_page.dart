import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/admin_shell.dart';
import '../domain/admin_guided_trash.dart';

class AdminGuidedTrashPage extends StatefulWidget {
  const AdminGuidedTrashPage({super.key, required this.repository});
  final AdminGuidedTrashRepository repository;

  @override
  State<AdminGuidedTrashPage> createState() => _AdminGuidedTrashPageState();
}

class _AdminGuidedTrashPageState extends State<AdminGuidedTrashPage> {
  List<GuidedTrashEntry>? _entries;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.repository.list();
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cargar la papelera. Reintenta para comprobar su estado.',
        );
      }
    }
  }

  Future<void> _restore(GuidedTrashEntry entry) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => EntrenaDialog(
          title: const Text('¿Recuperar programa?'),
          content: Text(
            entry.isWork
                ? '«${entry.name}» volverá a Continuar trabajando con su contenido guardado.'
                : 'Se recuperarán todas las versiones y trabajos vinculados de «${entry.name}». Los borradores seguirán como borradores. Lo que estaba publicado quedará retirado hasta que lo revises y publiques de nuevo.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Recuperar',
              onPrimary: () => Navigator.of(ctx).pop(true),
              secondary: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      await widget.repository.restore(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Programa recuperado. Puedes continuar desde Programas guiados.',
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar la recuperación. Actualiza la papelera antes de reintentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(title: const Text('Papelera de programas')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Papelera de programas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Recupera programas y trabajos incompletos. Se conservan las sesiones, sus enlaces y los resultados. La papelera no se vacía automáticamente.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => context.canPop()
                            ? context.pop()
                            : context.go('/guided-programs'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver a programas'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar papelera'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!),
              ),
            if (_entries == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_entries?.isEmpty == true)
              const Text('La papelera está vacía.'),
            for (final entry in _entries ?? <GuidedTrashEntry>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.isWork
                            ? 'Trabajo incompleto'
                            : '${entry.versions} ${entry.versions == 1 ? 'versión' : 'versiones'} · ${entry.workCount} ${entry.workCount == 1 ? 'trabajo vinculado' : 'trabajos vinculados'}',
                      ),
                      Text(
                        'En papelera desde ${entry.trashedAt.toLocal().toString().substring(0, 16)}',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _restore(entry),
                        icon: const Icon(Icons.restore_from_trash_outlined),
                        label: const Text('Recuperar programa'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
