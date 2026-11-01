import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:entrenaop/features/profile/presentation/edit_profile_name.dart';
import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:entrenaop/features/profile/presentation/choose_birth_date.dart';
import 'package:entrenaop/features/profile/presentation/widgets/app_build_info_tile.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/profile_photo/domain.dart';

import '../profile_photo_control.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.birthDateRepository,
    this.nameRepository,
    this.photoRepository,
    this.isRootDestination = true,
  });

  final ProfileBirthDateRepository birthDateRepository;
  final ProfileNameRepository? nameRepository;
  final ProfilePhotoRepository? photoRepository;
  final bool isRootDestination;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<DateTime?> _birthDate = widget.birthDateRepository.get();
  bool _savingBirthDate = false;

  Future<void> _editName() async {
    final auth = context.read<AuthCubit>();
    final state = auth.state;
    final repository = widget.nameRepository;
    if (state is! AuthAuthenticated || repository == null) return;
    final owner = state.user.id;
    final saved = await editProfileName(
      context,
      current: state.user.fullName ?? '',
      save: (name) => repository.save(owner, name),
    );
    if (!mounted || saved == null) return;
    auth.profileNameSaved(owner, saved);
  }

  Future<void> _editBirthDate(DateTime? current) async {
    final chosen = await chooseBirthDate(context, current: current);
    if (chosen == null || !mounted) return;
    setState(() => _savingBirthDate = true);
    try {
      await widget.birthDateRepository.save(chosen);
      if (!mounted) return;
      setState(() {
        _birthDate = widget.birthDateRepository.get();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la fecha de nacimiento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingBirthDate = false);
    }
  }

  Future<void> _refresh() async {
    final birth = widget.birthDateRepository.get();
    setState(() {
      _birthDate = birth;
    });
    try {
      await birth;
    } catch (_) {
      // El FutureBuilder mantiene su error y el acceso de reintento.
    }
  }

  void _open(String route) => context.push(route);

  Widget _identityCard(UserEntity? user, String displayName) => EntrenaCard(
    tone: EntrenaCardTone.progress,
    padding: const EdgeInsets.all(24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < MediaQuery.textScalerOf(context).scale(260);
        final avatar = user != null && widget.photoRepository != null
            ? ProfilePhotoControl(
                key: ValueKey('profile-photo-${user.id}'),
                repository: widget.photoRepository!,
                name: displayName,
              )
            : CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFFF8A50),
                foregroundColor: const Color(0xFF20120D),
                child: Text(
                  displayName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            if (user != null && widget.nameRepository != null)
              TextButton.icon(
                onPressed: _editName,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Cambiar nombre'),
              ),
            if (user != null) ...[
              const SizedBox(height: 4),
              Text(
                user.email,
                overflow: stacked ? null : TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'En EntrenaOP desde ${DateFormat('MM/yyyy').format(user.createdAt)}',
                style: const TextStyle(color: Color(0xFFFFB08A), fontSize: 12),
              ),
            ],
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
            SizedBox(width: stacked ? null : 18, height: stacked ? 16 : null),
            if (stacked) details else Expanded(child: details),
          ],
        );
      },
    ),
  );

  Widget _evolutionCard() => EntrenaCard(
    tone: EntrenaCardTone.progress,
    onTap: () => _open('/assessment/history'),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(220)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_outlined),
                  Spacer(),
                  Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Mi evolución',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('Historial, resultados y marcas'),
            ],
          );
        }
        return const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.insights_outlined),
          title: Text('Mi evolución'),
          subtitle: Text('Historial, resultados y marcas'),
          trailing: Icon(Icons.chevron_right),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final name = user?.fullName?.trim();
    final displayName = name == null || name.isEmpty ? 'Tu perfil' : name;

    return SectionRefreshBoundary(
      location: '/profile',
      onVisible: () => _refresh(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Perfil'),
          automaticallyImplyLeading: !widget.isRootDestination,
          leading: widget.isRootDestination
              ? null
              : BackButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _identityCard(user, displayName),
                        const SizedBox(height: 26),
                        _evolutionCard(),
                        const SizedBox(height: 22),
                        FutureBuilder<DateTime?>(
                          future: _birthDate,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Card(
                                child: ListTile(
                                  title: const Text(
                                    'No pudimos cargar tu fecha de nacimiento',
                                  ),
                                  trailing: const Icon(Icons.refresh),
                                  onTap: () => setState(() {
                                    _birthDate = widget.birthDateRepository
                                        .get();
                                  }),
                                ),
                              );
                            }
                            if (!snapshot.hasData &&
                                snapshot.connectionState !=
                                    ConnectionState.done) {
                              return const LinearProgressIndicator();
                            }
                            final birthDate = snapshot.data;
                            return Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.cake_outlined,
                                  color: Color(0xFFFF8A50),
                                ),
                                title: const Text('Fecha de nacimiento'),
                                subtitle: Text(
                                  birthDate == null
                                      ? 'Añádela para aplicar los baremos por edad.'
                                      : '${DateFormat('dd/MM/yyyy').format(birthDate)} · ${ageOnDate(birthDate, DateTime.now())} años',
                                ),
                                trailing: _savingBirthDate
                                    ? const CircularProgressIndicator()
                                    : const Icon(Icons.edit_outlined),
                                onTap: _savingBirthDate
                                    ? null
                                    : () => _editBirthDate(birthDate),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.devices_other_outlined),
                            title: const Text('Dispositivos y conexiones'),
                            subtitle: const Text(
                              'Salud del móvil, Garmin y tus conexiones de entrenamiento.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open('/profile/connections'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.workspace_premium_outlined,
                            ),
                            title: const Text('Mi suscripción'),
                            subtitle: const Text('Descubre EntrenaOP Pro.'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open('/pro/subscription'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const AppBuildInfoTile(),
                        const SizedBox(height: 22),
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
        ),
      ),
    );
  }
}
