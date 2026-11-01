import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/profile_photo/domain.dart';

import '../../../../core/navigation/workspace_navigation_scope.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../coach_workspace/presentation/coach_workspace_scope.dart';
import '../../data/profile_birth_date_repository.dart';
import '../../data/profile_name_repository.dart';
import '../profile_photo_control.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.birthDateRepository,
    this.nameRepository,
    this.photoRepository,
    this.isRootDestination = true,
    super.key,
  });

  // Se conservan los parámetros de composición; los datos se consultan en Editar.
  final ProfileBirthDateRepository birthDateRepository;
  final ProfileNameRepository? nameRepository;
  final ProfilePhotoRepository? photoRepository;
  final bool isRootDestination;

  Widget _identityCard(BuildContext context, UserEntity? user) {
    final name = user?.fullName?.trim();
    final displayName = name == null || name.isEmpty ? 'Tu perfil' : name;
    return EntrenaCard(
      tone: EntrenaCardTone.progress,
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/profile/edit'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth <
              MediaQuery.textScalerOf(context).scale(210);
          final avatar = user != null && photoRepository != null
              ? ProfilePhotoControl(
                  key: ValueKey('profile-photo-${user.id}'),
                  repository: photoRepository!,
                  name: displayName,
                  radius: 26,
                )
              : CircleAvatar(
                  radius: 26,
                  child: Text(displayName.characters.first.toUpperCase()),
                );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Editar perfil'),
            ],
          );
          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              avatar,
              SizedBox(width: stacked ? null : 14, height: stacked ? 12 : null),
              if (stacked) details else Expanded(child: details),
              if (!stacked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _destination({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    EntrenaCardTone tone = EntrenaCardTone.neutral,
    int unread = 0,
  }) => EntrenaCard(
    tone: tone,
    onTap: onTap,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final leading = unread > 0
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Badge.count(
                  count: unread,
                  maxCount: 99,
                  child: Icon(icon),
                ),
              )
            : Icon(icon);
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        );
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(220)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  leading,
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              details,
            ],
          );
        }
        return Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(child: details),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    buildWhen: (_, next) =>
        next is AuthAuthenticated || next is AuthUnauthenticated,
    builder: (context, auth) {
      final user = auth is AuthAuthenticated ? auth.user : null;
      final workspace = CoachWorkspaceScope.maybeOf(context)?.controller;
      final navigation = WorkspaceNavigationScope.maybeOf(context);
      final unread = workspace?.unread ?? 0;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          automaticallyImplyLeading: !isRootDestination,
          leading: isRootDestination
              ? null
              : BackButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
          actions: [
            IconButton(
              tooltip: 'Ajustes',
              onPressed: () => context.push('/profile/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
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
                      _identityCard(context, user),
                      const SizedBox(height: 18),
                      _destination(
                        icon: Icons.insights_outlined,
                        title: 'Mi evolución',
                        subtitle: 'Historial, resultados y marcas',
                        tone: EntrenaCardTone.progress,
                        onTap: () => context.push('/assessment/history'),
                      ),
                      const SizedBox(height: 14),
                      _destination(
                        icon: Icons.devices_other_outlined,
                        title: 'Dispositivos y conexiones',
                        subtitle: 'Salud, Garmin y relojes',
                        onTap: () => context.push('/profile/connections'),
                      ),
                      if (workspace?.enabled == true && navigation != null) ...[
                        const SizedBox(height: 22),
                        _destination(
                          icon: Icons.work_outline,
                          title: 'Entrar como preparador',
                          subtitle: unread == 0
                              ? 'Tu espacio profesional'
                              : unread == 1
                              ? '1 novedad profesional'
                              : '$unread novedades profesionales',
                          tone: EntrenaCardTone.quiet,
                          unread: unread,
                          onTap: navigation.enterProfessional,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
