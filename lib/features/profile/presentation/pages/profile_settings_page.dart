import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../domain/app_support.dart';
import '../widgets/app_build_info_tile.dart';
import '../widgets/profile_option_tile.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({
    this.resources = const AppSupportResources(),
    this.openLink,
    super.key,
  });
  final AppSupportResources resources;
  final OpenSupportLink? openLink;

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await openLink?.call(uri) ?? false;
    } catch (_) {
      /* Mostrar el mismo error recuperable. */
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hemos podido abrir el enlace. Vuelve a intentarlo.',
          ),
        ),
      );
    }
  }

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            EntrenaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    rows[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _option(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    String? subtitle,
  }) => ProfileOptionTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );

  Widget _link(BuildContext context, IconData icon, String title, Uri uri) =>
      ProfileOptionTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new_rounded),
        onTap: () => _open(context, uri),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ajustes'),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(context, 'Cuenta y Pro', [
                    _option(
                      context,
                      Icons.workspace_premium_outlined,
                      'Mi suscripción',
                      '/pro/subscription',
                      subtitle: 'EntrenaOP Pro, acceso y compras',
                    ),
                    _option(
                      context,
                      Icons.notifications_none_rounded,
                      'Notificaciones',
                      '/profile/settings/notifications',
                    ),
                    if (resources.promotion case final uri?)
                      _link(
                        context,
                        Icons.redeem_outlined,
                        'Canjear código promocional',
                        uri,
                      ),
                  ]),
                  _section(context, 'Ayuda', [
                    _option(
                      context,
                      Icons.help_outline_rounded,
                      'Preguntas frecuentes',
                      '/profile/settings/help',
                    ),
                    _option(
                      context,
                      Icons.chat_bubble_outline_rounded,
                      'Informar de un problema',
                      '/profile/settings/support',
                    ),
                  ]),
                  _section(context, 'Información', [
                    if (resources.rating case final uri?)
                      _link(
                        context,
                        Icons.star_outline_rounded,
                        'Valorar EntrenaOP',
                        uri,
                      ),
                    if (resources.instagram case final uri?)
                      _link(
                        context,
                        Icons.open_in_new_rounded,
                        'Instagram',
                        uri,
                      ),
                    _option(
                      context,
                      Icons.description_outlined,
                      'Condiciones de uso',
                      '/terms',
                    ),
                    _option(
                      context,
                      Icons.privacy_tip_outlined,
                      'Privacidad',
                      '/privacy',
                    ),
                  ]),
                  const AppBuildInfoTile(),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
