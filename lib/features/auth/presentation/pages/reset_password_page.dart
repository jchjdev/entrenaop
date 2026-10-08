import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/widgets/auth_page_shell.dart';
import 'package:entrenaop/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
    listener: (context, state) {
      if (state is AuthUnauthenticated) {
        context.go('/');
      }
      if (state is AuthPasswordRecovery && state.passwordUpdated) {
        _password.clear();
        _confirmation.clear();
      }
    },
    builder: (context, state) {
      if (state is! AuthPasswordRecovery) return const AccountLinkErrorPage();
      return AuthPageShell(
        title: state.passwordUpdated
            ? 'Contraseña actualizada'
            : 'Crea una nueva contraseña',
        subtitle: state.passwordUpdated
            ? 'Ya puedes acceder a EntrenaOP con tu nueva contraseña.'
            : 'El enlace ha sido validado. Elige la nueva contraseña de tu cuenta.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.passwordUpdated) ...[
              const Icon(Icons.check_circle_outline_rounded, size: 52),
              const SizedBox(height: 20),
              Text(state.email),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isSaving
                    ? null
                    : context.read<AuthCubit>().finishPasswordRecovery,
                child: Text(
                  state.isSaving ? 'Cerrando recuperación…' : 'Ir al acceso',
                ),
              ),
            ] else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(state.email),
                    const SizedBox(height: 20),
                    AuthTextField(
                      controller: _password,
                      label: 'Nueva contraseña',
                      enabled: !state.isSaving,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: state.isSaving
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Utiliza al menos 8 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _confirmation,
                      label: 'Repite la nueva contraseña',
                      enabled: !state.isSaving,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_reset_rounded,
                      validator: (value) => value != _password.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                      onFieldSubmitted: (_) {
                        if (!state.isSaving && _form.currentState!.validate()) {
                          context.read<AuthCubit>().updateRecoveredPassword(
                            _password.text,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isSaving
                          ? null
                          : () {
                              if (_form.currentState!.validate()) {
                                context
                                    .read<AuthCubit>()
                                    .updateRecoveredPassword(_password.text);
                              }
                            },
                      child: Text(
                        state.isSaving
                            ? 'Guardando…'
                            : 'Guardar nueva contraseña',
                      ),
                    ),
                    TextButton(
                      onPressed: state.isSaving
                          ? null
                          : context.read<AuthCubit>().finishPasswordRecovery,
                      child: const Text('Cancelar recuperación'),
                    ),
                  ],
                ),
              ),
            if (state.message != null) ...[
              const SizedBox(height: 16),
              Text(state.message!),
            ],
          ],
        ),
      );
    },
  );
}

class AccountLinkErrorPage extends StatelessWidget {
  const AccountLinkErrorPage({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) => AuthPageShell(
      title: 'Necesitas un enlace nuevo',
      subtitle: state is AuthLinkError ? state.message : 'Abre el enlace de recuperación recibido por correo. Si ha caducado o ya se usó, solicita uno nuevo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () {
              context.read<AuthCubit>().dismissAccountNotice();
              context.go('/forgot-password');
            },
            child: const Text('Solicitar enlace de recuperación'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthCubit>().dismissAccountNotice();
              context.go('/');
            },
            child: const Text('Volver al acceso'),
          ),
        ],
      ),
    ),
  );
}
