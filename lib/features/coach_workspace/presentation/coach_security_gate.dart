import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_security.dart';

import 'coach_workspace_scope.dart';

class CoachSecurityGate extends StatelessWidget {
  const CoachSecurityGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.maybeOf(context);
    if (scope == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Volver a mi entrenamiento'),
          ),
        ),
      );
    }
    final controller = scope.controller;
    if (controller.canRead) return child;
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Tu espacio profesional',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (controller.error != null) ...[
                Text(controller.error!),
                FilledButton(
                  onPressed: controller.refresh,
                  child: const Text('Reintentar'),
                ),
              ] else if (!controller.enabled)
                const Text(
                  'Tu cuenta no tiene acceso profesional vigente. Puedes seguir usando tu espacio de deportista.',
                )
              else
                CoachMfaChallenge(
                  security: controller.security,
                  onComplete: controller.refresh,
                ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Volver a mi entrenamiento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoachMfaChallenge extends StatefulWidget {
  const CoachMfaChallenge({
    super.key,
    required this.security,
    required this.onComplete,
  });
  final TrainerSecurity security;
  final Future<void> Function() onComplete;
  @override
  State<CoachMfaChallenge> createState() => _CoachMfaChallengeState();
}

class _CoachMfaChallengeState extends State<CoachMfaChallenge> {
  final _code = TextEditingController();
  List<String>? _factors;
  String? _factor, _error;
  TrainerTotpSetup? _setup;
  bool _busy = false, _verified = false;
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
    try {
      final factors = await widget.security.factors();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _factor = factors.firstOrNull;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo consultar el autenticador.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _factor == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Introduce las seis cifras de tu autenticador.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_verified) {
        await widget.security.verify(_factor!, _code.text);
        _verified = true;
      }
      if (!await widget.security.assured()) {
        throw StateError('Verificación pendiente');
      }
      if (!mounted) return;
      _code.clear();
      _setup = null;
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo verificar. Comprueba el código actual y la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await widget.security.enroll();
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _factor = setup.id;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo configurar el autenticador. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _setup = null;
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Verifica tu autenticador para consultar a tus alumnos. Utiliza el mismo que en Trainer web.',
      ),
      const SizedBox(height: 16),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (_factors == null && !_busy)
        TextButton(
          onPressed: _load,
          child: const Text('Consultar autenticadores'),
        ),
      if (_factors?.isEmpty == true && _setup == null)
        FilledButton(
          onPressed: _busy ? null : _enroll,
          child: const Text('Configurar autenticador'),
        ),
      if (_setup case final setup?) ...[
        const Text(
          'Añade esta clave manualmente a tu autenticador y confirma su primer código.',
        ),
        SelectableText(setup.secret),
      ],
      if ((_factors?.length ?? 0) > 1)
        DropdownButtonFormField<String>(
          initialValue: _factor,
          decoration: const InputDecoration(labelText: 'Autenticador'),
          items: [
            for (var i = 0; i < _factors!.length; i++)
              DropdownMenuItem(
                value: _factors![i],
                child: Text('Autenticador ${i + 1}'),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _factor = value;
                  _verified = false;
                }),
        ),
      if (_factor != null) ...[
        TextField(
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(labelText: 'Código de seis cifras'),
          onChanged: (_) => _verified = false,
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: const Text('Verificar y entrar'),
        ),
      ],
    ],
  );
}
