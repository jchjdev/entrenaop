import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trainer_access/trainer_security.dart';

class TrainerSecurityPage extends StatefulWidget {
  const TrainerSecurityPage({
    super.key,
    required this.repository,
    required this.onComplete,
    required this.onSignOut,
  });
  final TrainerSecurity repository;
  final VoidCallback onComplete;
  final Future<void> Function() onSignOut;
  @override
  State<TrainerSecurityPage> createState() => _TrainerSecurityPageState();
}

class _TrainerSecurityPageState extends State<TrainerSecurityPage> {
  final _code = TextEditingController();
  TrainerTotpSetup? _setup;
  List<String> _factors = [];
  String? _factor, _error;
  bool _busy = true, _loaded = false, _verified = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _setup = null;
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se ha podido confirmar la verificación. Revisa el código actual y la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    try {
      final factors = await widget.repository.factors();
      if (mounted) {
        setState(() {
          _factors = factors;
          _factor = factors.firstOrNull;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo consultar el autenticador. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const EntrenaWordmark(),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _run(widget.onSignOut),
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Protege tu espacio profesional',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Para acceder a tus clientes es obligatorio verificar tu autenticador. Si ya lo usas con EntrenaOP, utiliza ese mismo factor.',
            ),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (!_loaded && !_busy)
              TextButton(
                onPressed: () {
                  setState(() => _busy = true);
                  _load();
                },
                child: const Text('Reintentar'),
              ),
            if (_loaded && _factors.isEmpty && _setup == null)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final setup = await widget.repository.enroll();
                        if (mounted) {
                          setState(() {
                            _setup = setup;
                            _factor = setup.id;
                          });
                        }
                      }),
                child: const Text('Configurar autenticador'),
              ),
            if (_setup case final setup?) ...[
              const Text('Escanea este QR con tu aplicación de autenticación.'),
              const SizedBox(height: 16),
              Center(child: totpQr(setup.qr)),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Introducir la clave manualmente'),
                children: [
                  SelectableText(setup.secret),
                  TextButton(
                    onPressed: () => _run(() async {
                      await Clipboard.setData(
                        ClipboardData(text: setup.secret),
                      );
                    }),
                    child: const Text('Copiar clave'),
                  ),
                ],
              ),
            ],
            if (_factors.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _factor,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Autenticador'),
                items: [
                  for (var i = 0; i < _factors.length; i++)
                    DropdownMenuItem(
                      value: _factors[i],
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
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                onChanged: (_) => _verified = false,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código de seis cifras',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: const Text('Verificar y entrar'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  Future<void> _verify() => _run(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _error = 'Introduce las seis cifras de tu autenticador.');
      return;
    }
    // Si Auth ya confirmó el OTP, reintentar la consulta de servidor no vuelve
    // a consumir el mismo código de un solo uso.
    if (!_verified) {
      await widget.repository.verify(_factor!, _code.text);
      _verified = true;
    }
    if (!await widget.repository.assured()) {
      throw StateError('Segundo factor pendiente.');
    }
    if (!mounted) return;
    _setup = null;
    _code.clear();
    widget.onComplete();
  });
}
