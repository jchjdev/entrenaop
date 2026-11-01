import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../widgets/app_build_info_tile.dart';
import '../widgets/profile_option_tile.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

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
                  Card(
                    child: ProfileOptionTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Mi suscripción'),
                      subtitle: const Text('Descubre EntrenaOP Pro.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/pro/subscription'),
                    ),
                  ),
                  const SizedBox(height: 18),
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
