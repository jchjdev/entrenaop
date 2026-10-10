import 'dart:async';

import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/widgets/auth_page_shell.dart';
import 'package:entrenaop/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AccountEmailPage extends StatefulWidget {
  const AccountEmailPage({
    super.key,
    this.confirmation = false,
    this.initialEmail = '',
  });
  final bool confirmation;
  final String initialEmail;
  @override
  State<AccountEmailPage> createState() => _AccountEmailPageState();
}

class _AccountEmailPageState extends State<AccountEmailPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    _email.text = switch (state) {
      AuthEmailConfirmationRequired(:final email) => email,
      AuthPasswordResetRequest(:final email) => email,
      _ => widget.initialEmail,
    };
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthCubit>();
    if (widget.confirmation) {
      unawaited(auth.resendConfirmation(_email.text.trim()));
    } else {
      unawaited(auth.requestPasswordReset(_email.text.trim()));
    }
  }

  void _back() {
    context.read<AuthCubit>().dismissAccountNotice();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      final busy = switch (state) {
        AuthEmailConfirmationRequired(:final isSending) => isSending,
        AuthPasswordResetRequest(:final isSending) => isSending,
        _ => false,
      };
      final sent = state is AuthPasswordResetRequest && state.sent;
      final message = switch (state) {
        AuthEmailConfirmationRequired(:final message) => message,
        AuthPasswordResetRequest(:final message) => message,
        _ => null,
      };
      final retryAt = switch (state) {
        AuthEmailConfirmationRequired(:final retryAt) => retryAt,
        AuthPasswordResetRequest(:final retryAt) => retryAt,
        _ => null,
      };
      final remaining = retryAt == null
          ? 0
          : (retryAt.difference(DateTime.now()).inMilliseconds / 1000)
                .ceil()
                .clamp(0, 60);
      return AuthPageShell(
        title: widget.confirmation
            ? 'Confirma tu correo'
            : sent
            ? 'Revisa tu correo'
            : 'Recupera tu contraseña',
        subtitle: widget.confirmation
            ? 'Abre el enlace del correo de EntrenaOP para activar tu cuenta.'
            : sent
            ? 'Si existe una cuenta con ese correo, recibirás un enlace para crear una nueva contraseña.'
            : 'Te enviaremos un enlace para crear una nueva contraseña.',
        onBack: busy ? null : _back,
        footer: TextButton(
          onPressed: busy ? null : _back,
          child: Text(
            widget.confirmation ? 'Iniciar sesión' : 'Volver al acceso',
          ),
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.confirmation || sent) ...[
                const Icon(Icons.mark_email_unread_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Revisa también la carpeta de spam. Abre el enlace en el mismo navegador o dispositivo donde solicitaste el correo. Si pediste varios, utiliza el más reciente.',
                ),
                if (widget.confirmation) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Si abriste el enlace en otro navegador y apareció un error, tu correo puede estar confirmado. Prueba a iniciar sesión con tu contraseña antes de pedir otro correo.',
                  ),
                ],
                const SizedBox(height: 20),
              ],
              AuthTextField(
                controller: _email,
                label: 'Correo electrónico',
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.alternate_email_rounded,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.contains('@') && email.contains('.')
                      ? null
                      : 'Introduce un correo válido.';
                },
                onFieldSubmitted: (_) {
                  if (!busy && remaining == 0) _submit();
                },
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message, key: const ValueKey('account-email-message')),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy || remaining > 0 ? null : _submit,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  busy
                      ? 'Enviando…'
                      : remaining > 0
                      ? 'Reenviar en ${remaining}s'
                      : widget.confirmation || sent
                      ? 'Reenviar correo'
                      : 'Enviar enlace',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
