import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.preparations});

  final PreparationGoalRepository preparations;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<List<PreparationGoal>> _activeGoals = widget.preparations
      .getActiveGoals();

  void _reloadGoals() => setState(() {
    _activeGoals = widget.preparations.getActiveGoals();
  });

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _reloadGoals();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final name = user?.fullName?.trim();
    final displayName = name == null || name.isEmpty ? 'Tu perfil' : name;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Perfil'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _reloadGoals();
            await _activeGoals;
          },
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF372016), Color(0xFF171717)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF6B3824)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
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
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (user != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'En EntrenaOP desde ${DateFormat('MM/yyyy').format(user.createdAt)}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFB08A),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Mis preparaciones',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Cada programa mantiene sus objetivos y controles por separado.',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<PreparationGoal>>(
                        future: _activeGoals,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Card(
                              child: ListTile(
                                title: const Text(
                                  'No pudimos cargar tus preparaciones',
                                ),
                                trailing: const Icon(Icons.refresh),
                                onTap: _reloadGoals,
                              ),
                            );
                          }
                          final goals = snapshot.data!;
                          return Column(
                            children: [
                              if (goals.isEmpty)
                                const Card(
                                  child: ListTile(
                                    leading: Icon(Icons.flag_outlined),
                                    title: Text(
                                      'Aún no sigues una preparación',
                                    ),
                                    subtitle: Text(
                                      'Elige un programa para organizar tus objetivos.',
                                    ),
                                  ),
                                )
                              else
                                for (final goal in goals)
                                  Card(
                                    color: const Color(0xFF171717),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.flag_outlined,
                                        color: Color(0xFFFF8A50),
                                      ),
                                      title: Text(goal.program.name),
                                      subtitle: Text(
                                        goal.targetDate == null
                                            ? 'Sin fecha objetivo'
                                            : 'Objetivo · ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: goal.id == null
                                          ? null
                                          : () =>
                                                _open('/plan/goal/${goal.id}'),
                                    ),
                                  ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _open('/plan/goal'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Gestionar preparaciones'),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Tu entrenamiento',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF171717),
                        child: ListTile(
                          leading: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFFFF8A50),
                          ),
                          title: const Text('Disponibilidad y material'),
                          subtitle: const Text(
                            'Ajusta tus preferencias de entrenamiento.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open('/plan/preferences'),
                        ),
                      ),
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
    );
  }
}
