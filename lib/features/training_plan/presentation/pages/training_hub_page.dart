import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
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
                      'Sigue tus entrenamientos y registra cómo te van. Tu programa adapta las próximas sesiones con tus resultados.',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                    const SizedBox(height: 22),
                    _WeeklyScheduleCard(
                      onOpen: () => context.push('/plan/week'),
                    ),
                    const SizedBox(height: 12),
                    _AvailableSessionCard(
                      onOpen: () => context.push('/library'),
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Mis sesiones',
                      subtitle: 'Rutinas creadas y guardadas por ti.',
                    ),
                    const SizedBox(height: 10),
                    _PersonalSessionsCard(
                      onOpen: () => context.push('/plan/library?tab=personal'),
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Configuración del plan',
                      subtitle: 'Objetivo, tiempo disponible y material.',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      onGoal: () => context.push('/plan/goal'),
                      onPreferences: () => context.push('/profile/preferences'),
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
    return EntrenaCard(
      tone: EntrenaCardTone.accent,
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.visuals.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.calendar_view_week_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi semana',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
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
    );
  }
}

class _AvailableSessionCard extends StatelessWidget {
  const _AvailableSessionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return EntrenaCard(
      tone: EntrenaCardTone.neutral,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'EXPLORA Y CREA',
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
            'Sesiones y ejercicios de EntrenaOP, junto a los que creas tú.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Abrir biblioteca'),
          ),
        ],
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
    return EntrenaCard(
      tone: EntrenaCardTone.neutral,
      onTap: onOpen,
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
