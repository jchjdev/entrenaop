import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'trainer_account_access.dart';

enum TrainerAccountForm { register, recover, confirm }

class TrainerAccountFrame extends StatelessWidget {
  const TrainerAccountFrame({
    super.key,
    required this.title,
    required this.children,
    this.back = true,
  });
  final String title;
  final List<Widget> children;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              tooltip: 'Volver a entrar',
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back),
            )
          : null,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: EntrenaWordmark(width: 190),
            ),
            const SizedBox(height: 28),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class TrainerAccountFormPage extends StatefulWidget {
  const TrainerAccountFormPage({
    super.key,
    required this.accounts,
    required this.mode,
  });
  final TrainerAccountAccess accounts;
  final TrainerAccountForm mode;
  @override
  State<TrainerAccountFormPage> createState() => _TrainerAccountFormPageState();
}

class _TrainerAccountFormPageState extends State<TrainerAccountFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _repeat = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _repeat]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (widget.mode) {
        case TrainerAccountForm.register:
          await widget.accounts.register(
            _name.text,
            _email.text,
            _password.text,
          );
        case TrainerAccountForm.recover:
          await widget.accounts.recover(_email.text);
        case TrainerAccountForm.confirm:
          await widget.accounts.resend(_email.text);
      }
      if (mounted) {
        _password.clear();
        _repeat.clear();
        setState(() => _sent = true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = trainerAccountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.mode == TrainerAccountForm.register;
    final title = switch (widget.mode) {
      TrainerAccountForm.register => 'Crea tu cuenta de EntrenaOP',
      TrainerAccountForm.recover => 'Recupera tu contraseña',
      TrainerAccountForm.confirm => 'Confirma tu correo',
    };
    return TrainerAccountFrame(
      title: _sent ? 'Revisa tu correo' : title,
      children: [
        if (_sent) ...[
          Text(
            widget.mode == TrainerAccountForm.recover
                ? 'Si hay una cuenta asociada a ese correo, recibirás un enlace para cambiar la contraseña. Ábrelo en este mismo navegador.'
                : 'Revisa el correo indicado y confirma tu cuenta desde este mismo navegador. Si ya tenías una cuenta, puedes iniciar sesión o recuperar la contraseña.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Crear cuenta no habilita el acceso profesional. EntrenaOP lo activa por separado.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Volver a iniciar sesión'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _sent = false),
            child: const Text('Corregir correo o volver a solicitarlo'),
          ),
        ] else
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (register) ...[
                    const Text(
                      'Si ya usas la app, tu cuenta es la misma. No necesitas instalarla para crear tu cuenta aquí.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Introduce tu nombre.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      return email.contains('@') && email.contains('.')
                          ? null
                          : 'Introduce un correo válido.';
                    },
                  ),
                  if (register) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) => (v?.length ?? 0) < 8
                          ? 'Utiliza al menos 8 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _repeat,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña',
                      ),
                      validator: (v) => v != _password.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_error != null) Text(_error!),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Enviando…'
                          : register
                          ? 'Crear cuenta'
                          : widget.mode == TrainerAccountForm.recover
                          ? 'Enviar enlace de recuperación'
                          : 'Reenviar confirmación',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    child: const Text('Ya tengo cuenta. Iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class TrainerPasswordUpdatePage extends StatefulWidget {
  const TrainerPasswordUpdatePage({super.key, required this.accounts});
  final TrainerAccountAccess accounts;
  @override
  State<TrainerPasswordUpdatePage> createState() =>
      _TrainerPasswordUpdatePageState();
}

class _TrainerPasswordUpdatePageState extends State<TrainerPasswordUpdatePage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(), _repeat = TextEditingController();
  bool _busy = false, _updated = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accounts.updatePassword(_password.text);
      if (mounted) {
        _password.clear();
        _repeat.clear();
        setState(() => _updated = true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = trainerAccountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accounts.finishRecovery();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) setState(() => _error = trainerAccountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TrainerAccountFrame(
    title: _updated ? 'Contraseña actualizada' : 'Crea una nueva contraseña',
    back: false,
    children: [
      Text(widget.accounts.email ?? ''),
      const SizedBox(height: 16),
      if (_updated) ...[
        const Text(
          'Ya puedes volver a entrar con tu nueva contraseña. Tu doble factor se conserva.',
        ),
        FilledButton(
          onPressed: _busy ? null : _finish,
          child: const Text('Volver a iniciar sesión'),
        ),
      ] else
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
                validator: (v) => (v?.length ?? 0) < 8
                    ? 'Utiliza al menos 8 caracteres.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repeat,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Repite la nueva contraseña',
                ),
                validator: (v) => v != _password.text
                    ? 'Las contraseñas no coinciden.'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Guardando…' : 'Guardar contraseña'),
              ),
            ],
          ),
        ),
      if (_error != null) Text(_error!),
    ],
  );
}

class TrainerAccountPendingPage extends StatefulWidget {
  const TrainerAccountPendingPage({
    super.key,
    required this.accounts,
    required this.onSignOut,
  });
  final TrainerAccountAccess accounts;
  final Future<void> Function() onSignOut;
  @override
  State<TrainerAccountPendingPage> createState() =>
      _TrainerAccountPendingPageState();
}

class _TrainerAccountPendingPageState extends State<TrainerAccountPendingPage> {
  TrainerAccountStatus? _status;
  String? _error;
  bool _busy = true;
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
      final status = await widget.accounts.status();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = trainerAccountError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TrainerAccountFrame(
    title: 'Tu cuenta de EntrenaOP',
    back: false,
    children: [
      Text(widget.accounts.email ?? ''),
      const SizedBox(height: 16),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (_status != null) ...[
        Text(
          _status!.enabled
              ? 'Tu acceso profesional está habilitado.'
              : _status!.professionalAccount
              ? 'Tu acceso profesional está inactivo. Puedes entrar para consultar tu servicio anterior.'
              : 'Tu cuenta ya está creada. El acceso profesional está pendiente de habilitación por EntrenaOP.',
        ),
        const SizedBox(height: 16),
        const Text(
          'No necesitas instalar la app del deportista para acceder como preparador. La misma cuenta te servirá también allí.',
        ),
        if (_status!.professionalAccount)
          FilledButton(
            onPressed: _busy ? null : () => context.go('/home'),
            child: const Text('Continuar al panel'),
          ),
      ],
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _busy ? null : _load,
        child: const Text('Comprobar acceso'),
      ),
      TextButton(
        onPressed: _busy ? null : widget.onSignOut,
        child: const Text('Cerrar sesión'),
      ),
    ],
  );
}
