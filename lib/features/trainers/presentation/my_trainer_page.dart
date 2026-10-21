import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/trainer_access.dart';

class MyTrainerPage extends StatefulWidget {
  const MyTrainerPage({super.key, required this.repository});
  final TrainerRepository repository;
  @override
  State<MyTrainerPage> createState() => _MyTrainerPageState();
}

class _MyTrainerPageState extends State<MyTrainerPage> {
  final _secret = TextEditingController();
  List<TrainerRelation> _active = [], _history = [];
  TrainerInvitationPreview? _preview;
  bool _busy = true, _loaded = false, _moreHistory = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final data = await Future.wait([
      widget.repository.relations(asTrainer: false),
      widget.repository.relations(asTrainer: false, ended: true),
    ]);
    if (!mounted) return;
    setState(() {
      _active = data[0];
      _history = data[1];
      _moreHistory = _history.length == 50;
      _loaded = true;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _loaded = false;
    });
    try {
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(TrainerRelation relation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => EntrenaDialog(
        title: const Text('Finalizar vínculo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dejarás de estar vinculado a ${relation.name}. Para volver necesitarás aceptar otra invitación. Tu historial personal se conserva.',
            ),
            const SizedBox(height: 20),
            EntrenaDialogActions(
              primaryLabel: 'Volver',
              onPrimary: () => Navigator.pop(context, false),
              secondary: [
                OutlinedButton(
                  style: EntrenaButtonStyles.destructive(context),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Finalizar vínculo'),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    await _run(() async {
      await widget.repository.endRelation(relation.id);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi preparador')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu preparación, acompañada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Acepta solo invitaciones de un preparador que conozcas. Puedes tener un único preparador activo.',
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!),
              ),
            if (_notice != null) Text(_notice!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
            if (_loaded) ...[
              if (_active.isEmpty) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Todavía no tienes preparador. Pídele su código de invitación.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _secret,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación',
                    hintText: 'Pega el código que te ha enviado',
                  ),
                  onChanged: (_) => setState(() => _preview = null),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final code = _secret.text.trim();
                          if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(code)) {
                            setState(
                              () => _error =
                                  'Pega el código completo de 64 caracteres.',
                            );
                            return;
                          }
                          final preview = await widget.repository.preview(code);
                          if (mounted) setState(() => _preview = preview);
                        }),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Ver invitación'),
                ),
                if (_preview case final preview?)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            preview.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Invitación válida hasta el ${trainerDate(preview.expiresAt)}',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Al aceptar confirmas el vínculo con este preparador. No se contrata ninguna suscripción ni se amplían tus cuotas de creación personal.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await widget.repository.accept(
                                      _secret.text.trim(),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _preview = null;
                                      _secret.clear();
                                      _notice = 'Vínculo aceptado.';
                                    });
                                    await _load();
                                  }),
                            child: const Text('Aceptar y vincularme'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else
                for (final relation in _active)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('PREPARADOR ACTIVO'),
                          const SizedBox(height: 8),
                          Text(
                            relation.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text('Desde el ${trainerDate(relation.acceptedAt)}'),
                          const SizedBox(height: 12),
                          const Text(
                            'Tu acceso personal Free o Pro se mantiene por separado.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _busy ? null : () => _end(relation),
                            child: const Text('Finalizar vínculo'),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Vínculos anteriores',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final relation in _history)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(relation.name),
                    subtitle: Text(
                      'Finalizado el ${trainerDate(relation.endedAt!)}',
                    ),
                  ),
                if (_moreHistory)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final more = await widget.repository.relations(
                              asTrainer: false,
                              ended: true,
                              before: _history.last,
                            );
                            if (mounted) {
                              setState(() {
                                _history.addAll(more);
                                _moreHistory = more.length == 50;
                              });
                            }
                          }),
                    child: const Text('Ver más vínculos'),
                  ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
