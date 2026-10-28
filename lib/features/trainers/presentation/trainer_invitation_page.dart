import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_invitation_entry.dart';

class TrainerInvitationPage extends StatelessWidget {
  const TrainerInvitationPage({
    super.key,
    required this.entry,
    required this.repository,
    required this.email,
    required this.signOut,
  });
  final TrainerInvitationEntry entry;
  final TrainerRepository repository;
  final String email;
  final Future<void> Function() signOut;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: entry,
    builder: (context, _) => _InvitationContent(
      key: ValueKey(entry.revision),
      entry: entry,
      repository: repository,
      email: email,
      signOut: signOut,
    ),
  );
}

class _InvitationContent extends StatefulWidget {
  const _InvitationContent({
    super.key,
    required this.entry,
    required this.repository,
    required this.email,
    required this.signOut,
  });
  final TrainerInvitationEntry entry;
  final TrainerRepository repository;
  final String email;
  final Future<void> Function() signOut;
  @override
  State<_InvitationContent> createState() => _InvitationContentState();
}

class _InvitationContentState extends State<_InvitationContent> {
  TrainerInvitationPreview? _preview;
  String? _error;
  bool _busy = true;
  late final int _revision = widget.entry.revision;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final secret = widget.entry.secret;
    try {
      if (secret == null) throw StateError('Invitación incompleta.');
      final value = await widget.repository.preview(secret);
      if (mounted && widget.entry.revision == _revision) {
        setState(() => _preview = value);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se puede abrir esta invitación. Comprueba que utilizas el correo al que te invitaron y que está confirmado, o pide un enlace nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final secret = widget.entry.secret;
    if (_busy || secret == null || _preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.accept(secret);
      if (!mounted || widget.entry.revision != _revision) return;
      // Salir antes de limpiar evita reconstruir una ficha sin invitación.
      context.go('/my-trainer');
      widget.entry.clear(_revision);
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invitación de tu preparador')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Tu cuenta: ${widget.email}'),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_preview case final preview?) ...[
          Text(preview.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'Te invita a entrenar con su seguimiento. Solo os vincularemos cuando pulses Aceptar preparador. Compartir tu calendario se decide por separado.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: const Text('Aceptar preparador'),
          ),
        ],
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Volver a comprobar'),
          ),
        ],
        TextButton(
          onPressed: _busy ? null : widget.signOut,
          child: const Text('Entrar con otra cuenta'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  context.go('/my-trainer');
                  widget.entry.clear(_revision);
                },
          child: const Text('Ahora no'),
        ),
      ],
    ),
  );
}
