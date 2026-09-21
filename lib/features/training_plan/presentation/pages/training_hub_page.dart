import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centro de organización del entrenamiento.
///
/// Aquí viven las sesiones y la planificación. La configuración personal se
/// mantiene accesible, pero deja de ocupar toda la pestaña «Mi plan».
class TrainingHubPage extends StatelessWidget {
  const TrainingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mi plan'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tu entrenamiento',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Organiza tu semana, tus sesiones y la configuración de tus preparaciones.',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                    const SizedBox(height: 22),
                    _WeeklyScheduleCard(
                      onOpen: () => context.push('/plan/week'),
                    ),
                    const SizedBox(height: 12),
                    _AvailableSessionCard(
                      onOpen: () => context.push('/plan/library'),
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Mis sesiones',
                      subtitle: 'Rutinas creadas y guardadas por ti.',
                    ),
                    const SizedBox(height: 10),
                    _PersonalSessionsCard(
                      onOpen: () => context.push('/plan/library'),
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Configuración del plan',
                      subtitle: 'Objetivo, tiempo disponible y material.',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      onGoal: () => context.push('/plan/goal'),
                      onPreferences: () => context.push('/plan/preferences'),
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
}

class _WeeklyScheduleCard extends StatelessWidget {
  const _WeeklyScheduleCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF172018),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF27452D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_view_week_rounded,
                  color: Color(0xFF9BE5A8),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi semana',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Programa tus sesiones y empieza la que toca hoy.',
                      style: TextStyle(color: Colors.white60, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableSessionCard extends StatelessWidget {
  const _AvailableSessionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF26150E),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SESIÓN DISPONIBLE',
                  style: TextStyle(
                    color: Color(0xFFFFC3A5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Biblioteca de EntrenaOP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Explora las sesiones públicas y consulta sus bloques antes de comenzar.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Abrir biblioteca'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class _PersonalSessionsCard extends StatelessWidget {
  const _PersonalSessionsCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151515),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: Color(0xFFFF8A50),
                size: 32,
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crear y gestionar sesiones',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Abre tus rutinas para editarlas, duplicarlas o crear una nueva.',
                      style: TextStyle(color: Colors.white60, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onGoal, required this.onPreferences});

  final VoidCallback onGoal;
  final VoidCallback onPreferences;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141414),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 7,
            ),
            leading: const Icon(Icons.flag_outlined, color: Color(0xFFFF8A50)),
            title: const Text('Preparaciones'),
            subtitle: const Text('Oposiciones, pruebas y fechas previstas.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onGoal,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 7,
            ),
            leading: const Icon(Icons.tune_rounded, color: Color(0xFFFF8A50)),
            title: const Text('Preferencias de entrenamiento'),
            subtitle: const Text('Disponibilidad, experiencia y material.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPreferences,
          ),
        ],
      ),
    );
  }
}
