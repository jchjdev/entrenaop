import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/admin_security_repository.dart';
import 'admin_totp_qr.dart';

class AdminSecurityPage extends StatefulWidget {
  const AdminSecurityPage({
    super.key,
    required this.repository,
    required this.onComplete,
  });
  final AdminSecurityRepository repository;
  final VoidCallback onComplete;
  @override
  State<AdminSecurityPage> createState() => _AdminSecurityPageState();
}

class _AdminSecurityPageState extends State<AdminSecurityPage> {
  final _passwordForm = GlobalKey<FormState>(),
      _codeForm = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _repeat = TextEditingController(),
      _code = TextEditingController();
  AdminSecurityStatus? _status;
  AdminTotpSetup? _setup;
  List<String> _factors = [];
  String? _factor, _error;
  bool _loading = true,
      _busy = false,
      _passwordChanged = false,
      _othersRevoked = false;
  bool _verified = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_current, _password, _repeat, _code]) {
      c.dispose();
    }
    _setup = null;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.repository.status();
      final factors = status.eligible
          ? await widget.repository.verifiedFactors()
          : <String>[];
      if (!mounted) return;
      setState(() {
        _status = status;
        _factors = factors;
        _factor = factors.firstOrNull;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo comprobar la seguridad de tu cuenta. Reintenta la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_busy || !_passwordForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.changePassword(_current.text, _password.text);
      // Nunca se guardan contraseñas ni secretos TOTP en preferencias o en logs.
      _passwordChanged = true;
      _current.clear();
      _password.clear();
      _repeat.clear();
      await widget.repository.revokeOtherSessions();
      _othersRevoked = true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _passwordChanged
              ? 'Contraseña actualizada. Falta confirmar el cierre de las otras sesiones; reinténtalo antes de continuar.'
              : 'No se pudo confirmar el cambio. Revisa la contraseña actual y la conexión. Si ya cambió, inicia sesión con la nueva.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.revokeOtherSessions();
      _othersRevoked = true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron cerrar las otras sesiones. Reintenta la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await widget.repository.enroll();
      if (mounted) {
        setState(() {
          _setup = setup;
          _factor = setup.factorId;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo preparar el autenticador. Reintenta; no se ha activado la protección todavía.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || !_codeForm.currentState!.validate() || _factor == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_verified) {
        await widget.repository.verify(_factor!, _code.text);
        _verified = true;
      }
      await widget.repository.enableRequirement();
      _setup = null;
      _code.clear();
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar la protección. Comprueba el código actual y la conexión; puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool repeat = false,
    bool current = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      obscureText: true,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        current ? AutofillHints.password : AutofillHints.newPassword,
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (current) {
          return value?.isNotEmpty == true
              ? null
              : 'Introduce tu contraseña actual.';
        }
        if (repeat) {
          return value == _password.text
              ? null
              : 'Las contraseñas no coinciden.';
        }
        if ((value?.runes.length ?? 0) < 16) {
          return 'Usa al menos 16 caracteres; puedes combinar varias palabras.';
        }
        if (utf8.encode(value!).length > 72) {
          return 'Usa como máximo 72 bytes de texto.';
        }
        if (value == _current.text) {
          return 'Elige una contraseña diferente de la actual.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seguridad del administrador'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _busy ? null : widget.repository.signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(child: EntrenaWordmark(width: 200)),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (_status == null)
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Reintentar comprobación'),
                    ),
                  if (_status?.eligible == false)
                    const Text(
                      'Esta cuenta no tiene permiso de administración.',
                    ),
                  if (_status?.eligible == true) ...[
                    if (_status!.mfaRequired && _status!.assured) ...[
                      const Text(
                        'Tu acceso administrativo ya está protegido con segundo factor.',
                      ),
                      FilledButton(
                        onPressed: widget.onComplete,
                        child: const Text('Entrar al admin'),
                      ),
                    ] else if (_status!.mfaRequired && _factors.isEmpty) ...[
                      const Text(
                        'No hay un autenticador verificado disponible. Recupera el acceso con el responsable del proyecto de Supabase; no se puede quitar esta protección desde el cliente.',
                      ),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Reintentar comprobación'),
                      ),
                    ] else ...[
                      if (!_status!.mfaRequired) ...[
                        Text(
                          '1. Cambia tu contraseña',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Usa una contraseña única, larga y guardada en tu gestor. Después configuraremos el autenticador. No compartas sus claves ni códigos.',
                        ),
                        const SizedBox(height: 16),
                        if (!_passwordChanged)
                          AutofillGroup(
                            child: Form(
                              key: _passwordForm,
                              child: Column(
                                children: [
                                  _passwordField(
                                    _current,
                                    'Contraseña actual',
                                    current: true,
                                  ),
                                  _passwordField(_password, 'Nueva contraseña'),
                                  _passwordField(
                                    _repeat,
                                    'Repetir nueva contraseña',
                                    repeat: true,
                                  ),
                                  FilledButton(
                                    onPressed: _busy ? null : _changePassword,
                                    child: const Text('Cambiar contraseña'),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            setState(() {
                                              _passwordChanged = true;
                                              _current.clear();
                                              _password.clear();
                                              _repeat.clear();
                                            });
                                            await _revokeOthers();
                                          },
                                    child: const Text(
                                      'Ya la cambié en la app del deportista',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_passwordChanged)
                          const Text('Contraseña actualizada.'),
                        if (_passwordChanged && !_othersRevoked)
                          OutlinedButton(
                            onPressed: _busy ? null : _revokeOthers,
                            child: const Text(
                              'Reintentar cierre de otras sesiones',
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                      if (_status!.mfaRequired ||
                          (_passwordChanged && _othersRevoked)) ...[
                        Text(
                          _status!.mfaRequired
                              ? 'Verifica tu acceso'
                              : '2. Activa tu autenticador',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Usa una aplicación como Google Authenticator, Microsoft Authenticator o tu gestor con TOTP. Guarda su copia de recuperación en un lugar seguro.',
                        ),
                        if (_factors.isEmpty && _setup == null)
                          FilledButton(
                            onPressed: _busy ? null : _enroll,
                            child: const Text('Configurar autenticador'),
                          ),
                        if (_setup != null) ...[
                          const SizedBox(height: 16),
                          Center(child: adminTotpQr(_setup!.qrSvg)),
                          const Text(
                            'Escanea el QR. Si no puedes, introduce manualmente esta clave en tu autenticador:',
                          ),
                          TextFormField(
                            initialValue: _setup!.secret,
                            readOnly: true,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Clave de configuración',
                              suffixIcon: IconButton(
                                tooltip: 'Copiar clave de configuración',
                                icon: const Icon(Icons.copy),
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: _setup!.secret),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_factors.length > 1)
                          DropdownButtonFormField<String>(
                            initialValue: _factor,
                            decoration: const InputDecoration(
                              labelText: 'Autenticador',
                            ),
                            items: [
                              for (var i = 0; i < _factors.length; i++)
                                DropdownMenuItem(
                                  value: _factors[i],
                                  child: Text('Autenticador ${i + 1}'),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _factor = value),
                          ),
                        if (_factor != null)
                          Form(
                            key: _codeForm,
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _code,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode,
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Código de seis cifras',
                                  ),
                                  validator: (value) =>
                                      RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                      ? null
                                      : 'Introduce las seis cifras del código actual.',
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _busy ? null : _verify,
                                  child: Text(
                                    _status!.mfaRequired
                                        ? 'Verificar y entrar'
                                        : 'Activar protección y entrar',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_busy)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
  );
}
