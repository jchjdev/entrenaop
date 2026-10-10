import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_pro_access_repository.dart';

class AdminProAccessPage extends StatefulWidget {
  const AdminProAccessPage({required this.repository, super.key});
  final AdminProAccessRepository repository;
  @override
  State<AdminProAccessPage> createState() => _AdminProAccessPageState();
}

class _AdminProAccessPageState extends State<AdminProAccessPage> {
  final _email = TextEditingController();
  final _reason = TextEditingController(text: 'Prueba de acceso Free/Pro');
  DevelopmentAccountAccess? _account;
  String? _error;
  bool _busy = false;
  int _days = 30;
  @override
  void dispose() {
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _perform(
    Future<DevelopmentAccountAccess> Function() operation,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await operation();
      if (mounted) setState(() => _account = account);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = const ['42501', '22023'].contains(error.code)
              ? error.message
              : 'No se ha podido gestionar el acceso. Vuelve a intentarlo.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se ha podido gestionar el acceso. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuentas de prueba')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Accesos Free/Pro en desarrollo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Concede Pro temporal sin cobrar. Retirar un acceso de prueba conserva los datos y el historial. No gestiona ni cancela compras de las tiendas.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de una cuenta registrada',
              ),
              onChanged: (_) => setState(() {
                _account = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _account = null);
                      _perform(
                        () => widget.repository.find(_email.text.trim()),
                      );
                    },
              child: const Text('Buscar cuenta'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!),
              ),
            if (_account case final account?) ...[
              const SizedBox(height: 24),
              Text(
                account.isPro ? 'Pro activo' : 'Cuenta Free',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (account.validUntil case final expiry?)
                Text(
                  'Acceso hasta ${expiry.toLocal().day}/${expiry.toLocal().month}/${expiry.toLocal().year}',
                ),
              Text(
                'Ejercicios propios: ${account.exercises} · Sesiones propias: ${account.sessions}',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _days,
                decoration: const InputDecoration(labelText: 'Duración de Pro'),
                items: [
                  for (final days in [1, 7, 30, 90])
                    DropdownMenuItem(value: days, child: Text('$days días')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _days = value!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Motivo del acceso de prueba',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _perform(
                        () => widget.repository.setAccess(
                          account.userId,
                          enabled: true,
                          days: _days,
                          reason: _reason.text.trim(),
                        ),
                      ),
                child: Text(
                  account.isPro
                      ? 'Renovar Pro de prueba'
                      : 'Conceder Pro de prueba',
                ),
              ),
              OutlinedButton(
                onPressed: _busy || !account.isPro
                    ? null
                    : () => _perform(
                        () => widget.repository.setAccess(
                          account.userId,
                          enabled: false,
                          days: _days,
                          reason: _reason.text.trim(),
                        ),
                      ),
                child: const Text('Retirar Pro de prueba'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
