import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/section_refresh_boundary.dart';
import '../../../../core/navigation/workflow_exit_guard.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/profile_birth_date_repository.dart';
import '../../data/profile_name_repository.dart';
import '../../domain/age_on_date.dart';
import '../choose_birth_date.dart';
import '../edit_profile_name.dart';
import '../widgets/profile_option_tile.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    required this.birthDateRepository,
    this.nameRepository,
    super.key,
  });

  final ProfileBirthDateRepository birthDateRepository;
  final ProfileNameRepository? nameRepository;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late Future<DateTime?> _birthDate = widget.birthDateRepository.get();
  bool _savingBirthDate = false;

  bool _owns(String id) {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthAuthenticated && auth.user.id == id;
  }

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
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthAuthenticated) return;
    final owner = auth.user.id;
    final chosen = await chooseBirthDate(context, current: current);
    if (chosen == null || !mounted || !_owns(owner)) return;
    setState(() => _savingBirthDate = true);
    try {
      await widget.birthDateRepository.save(chosen);
      if (!mounted || !_owns(owner)) return;
      setState(() {
        _birthDate = widget.birthDateRepository.get();
      });
    } catch (_) {
      if (!mounted || !_owns(owner)) return;
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
      // El campo conserva el error y su reintento sin ocultar los otros datos.
    }
  }

  void _back() {
    if (_savingBirthDate) return;
    context.canPop() ? context.pop() : context.go('/profile');
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    buildWhen: (_, next) =>
        next is AuthAuthenticated || next is AuthUnauthenticated,
    builder: (context, auth) {
      final user = auth is AuthAuthenticated ? auth.user : null;
      final name = user?.fullName?.trim();
      final displayName = name == null || name.isEmpty ? 'Tu perfil' : name;
      return SectionRefreshBoundary(
        location: '/profile/edit',
        onVisible: _refresh,
        child: WorkflowDraftGuard(
          hasUnsavedChanges: () => false,
          isBusy: () => _savingBirthDate,
          child: PopScope(
            canPop: !_savingBirthDate,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Editar perfil'),
                leading: BackButton(onPressed: _back),
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
                              EntrenaCard(
                                tone: EntrenaCardTone.progress,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    if (user != null) ...[
                                      const SizedBox(height: 8),
                                      Text(user.email),
                                      const SizedBox(height: 8),
                                      Text(
                                        'En EntrenaOP desde ${DateFormat('MM/yyyy').format(user.createdAt)}',
                                      ),
                                    ],
                                    if (widget.nameRepository != null) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: user == null
                                              ? null
                                              : _editName,
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Cambiar nombre'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              FutureBuilder<DateTime?>(
                                future: _birthDate,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Card(
                                      child: ProfileOptionTile(
                                        title: const Text(
                                          'No pudimos cargar tu fecha de nacimiento',
                                        ),
                                        trailing: const Icon(Icons.refresh),
                                        onTap: _refresh,
                                      ),
                                    );
                                  }
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const LinearProgressIndicator();
                                  }
                                  final birthDate = snapshot.data;
                                  return Card(
                                    child: ProfileOptionTile(
                                      leading: const Icon(Icons.cake_outlined),
                                      title: const Text('Fecha de nacimiento'),
                                      subtitle: Text(
                                        birthDate == null
                                            ? 'Añádela para aplicar los baremos por edad.'
                                            : '${DateFormat('dd/MM/yyyy').format(birthDate)} · ${ageOnDate(birthDate, DateTime.now())} años',
                                      ),
                                      trailing: _savingBirthDate
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.edit_outlined),
                                      onTap: _savingBirthDate
                                          ? null
                                          : () => _editBirthDate(birthDate),
                                    ),
                                  );
                                },
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
          ),
        ),
      );
    },
  );
}
