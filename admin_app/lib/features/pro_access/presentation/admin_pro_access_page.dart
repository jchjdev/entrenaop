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
  final _reason = TextEditingController(text: 'Acceso Pro gratuito');
  AdminAccountAccess? _account;
  String? _resolvedEmail, _error;
  bool _busy = false;
  int _days = 30;
  DateTime? _customDate;

  @override
  void dispose() {
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _perform(Future<AdminAccountAccess> Function() operation) async {
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

  Future<void> _changeGift(bool enabled) async {
    final account = _account;
    final email = _resolvedEmail;
    if (_busy ||
        account == null ||
        email == null ||
        !account.giftManagementEnabled) {
      return;
    }
    final reason = _reason.text.trim();
    if (reason.length < 3 ||
        reason.length > 200 ||
        (enabled && _days == -1 && _customDate == null)) {
      setState(
        () => _error =
            'Indica un motivo de al menos 3 caracteres y una fecha válida.',
      );
      return;
    }
    final now = DateTime.now();
    final until = !enabled || _days == 0
        ? null
        : _days == -1
        ? _customDate
        : DateTime(now.year, now.month, now.day + _days, 23, 59, 59);
    if (enabled && until != null && !until.isAfter(now)) {
      setState(() => _error = 'La fecha de fin debe ser posterior a hoy.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enabled ? 'Conceder Pro gratuito' : 'Retirar Pro gratuito'),
        content: Text(
          '$email\n\n${enabled
              ? until == null
                    ? 'Sin fecha de fin, hasta que lo retires. No se realizará ningún cobro.'
                    : 'Hasta el ${_date(until)}. No se realizará ningún cobro.'
              : account.subscriptionActive
              ? 'Se retira el acceso gratuito. La suscripción vigente seguirá dando acceso Pro.'
              : 'La cuenta pasará a Free. Sus datos e historial se conservan.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _account?.userId != account.userId ||
        _resolvedEmail != email) {
      return;
    }
    await _perform(
      () => widget.repository.setAccess(
        account.userId,
        enabled: enabled,
        validUntil: until,
        reason: reason,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day + 1);
    final chosen = await showDatePicker(
      context: context,
      initialDate: _customDate != null && _customDate!.isAfter(first)
          ? _customDate!
          : first,
      firstDate: first,
      lastDate: DateTime(now.year + 20, 12, 31),
      helpText: 'Fecha de fin del Pro gratuito',
      cancelText: 'Volver',
      confirmText: 'Seleccionar',
      fieldLabelText: 'Fecha de fin',
      errorFormatText: 'Fecha no válida',
      errorInvalidText: 'Elige una fecha posterior a hoy',
    );
    if (chosen != null && mounted) {
      setState(
        () => _customDate = DateTime(
          chosen.year,
          chosen.month,
          chosen.day,
          23,
          59,
          59,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuentas y Pro')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Gestiona el acceso de una cuenta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Busca por correo para consultar el acceso y conceder o retirar Pro gratuito. Las compras se gestionan por separado.',
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
                _resolvedEmail = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final email = _email.text.trim();
                      setState(() {
                        _account = null;
                        _resolvedEmail = email;
                      });
                      _perform(() => widget.repository.find(email));
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        account.isPro ? 'Pro activo' : 'Cuenta Free',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_resolvedEmail ?? ''),
                      const SizedBox(height: 12),
                      Text(
                        'Ejercicios propios: ${account.exercises} · Sesiones propias: ${account.sessions}',
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Pro gratuito',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        !account.freeProActive
                            ? 'Sin acceso gratuito vigente.'
                            : account.freeProValidUntil == null
                            ? 'Activo sin fecha de fin.'
                            : 'Activo hasta el ${_date(account.freeProValidUntil!)}.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Suscripción',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        !account.subscriptionActive
                            ? 'Sin suscripción vigente.'
                            : '${account.subscriptionEnvironment == 'SANDBOX' ? 'Suscripción de prueba' : 'Suscripción de tienda'} · ${account.subscriptionProduct == 'entrenaop_pro_annual' ? 'Anual' : 'Mensual'}',
                      ),
                      if (account.subscriptionActive &&
                          account.subscriptionValidUntil != null)
                        Text(
                          'Acceso hasta el ${_date(account.subscriptionValidUntil!)}.',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Administrar Pro gratuito',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Retirar un regalo no cancela una suscripción vigente. Los cambios quedan registrados con su motivo.',
              ),
              if (!account.giftManagementEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'La gestión de Pro gratuito no está habilitada en este entorno.',
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _days,
                decoration: const InputDecoration(
                  labelText: 'Duración del Pro gratuito',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sin fecha de fin')),
                  DropdownMenuItem(value: 1, child: Text('1 día')),
                  DropdownMenuItem(value: 7, child: Text('7 días')),
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                  DropdownMenuItem(value: 90, child: Text('90 días')),
                  DropdownMenuItem(value: 365, child: Text('1 año')),
                  DropdownMenuItem(
                    value: -1,
                    child: Text('Elegir fecha de fin'),
                  ),
                ],
                onChanged: _busy || !account.giftManagementEnabled
                    ? null
                    : (value) {
                        if (value != null) setState(() => _days = value);
                      },
              ),
              if (_days == -1)
                TextButton.icon(
                  onPressed: _busy || !account.giftManagementEnabled
                      ? null
                      : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _customDate == null
                        ? 'Seleccionar fecha'
                        : _date(_customDate!),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                enabled: !_busy && account.giftManagementEnabled,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Motivo del Pro gratuito',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || !account.giftManagementEnabled
                    ? null
                    : () => _changeGift(true),
                child: Text(
                  account.freeProActive
                      ? 'Cambiar Pro gratuito'
                      : 'Conceder Pro gratuito',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    _busy ||
                        !account.giftManagementEnabled ||
                        !account.freeProActive
                    ? null
                    : () => _changeGift(false),
                child: const Text('Retirar Pro gratuito'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
