import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.fitness_center_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 10),
            Text('EntrenaOP'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tu preparación empieza con datos reales',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Haz una primera evaluación y descubre exactamente desde dónde partes.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    color: const Color(0xFF171717),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 620;
                          const details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Tag(label: 'PRIMER PASO'),
                              SizedBox(height: 16),
                              Text(
                                'Evaluación inicial de ingreso',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tropa y marinería · 4 pruebas · Baremo oficial 2026',
                                style: TextStyle(
                                  color: Colors.white60,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          );

                          final action = SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  context.push('/assessment/initial'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE65100),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Comenzar evaluación'),
                            ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                details,
                                const SizedBox(height: 24),
                                action,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              const Expanded(flex: 3, child: details),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: action),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.gavel_outlined,
                          title: 'Baremo versionado',
                          text: 'Tus resultados conservarán la norma aplicada.',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.insights_outlined,
                          title: 'Resultado explicable',
                          text: 'Verás el margen exacto de cada prueba.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE65100).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF8A50),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF8A50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
