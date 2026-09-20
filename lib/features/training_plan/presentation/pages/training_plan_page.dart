import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TrainingPlanPage extends StatefulWidget {
  const TrainingPlanPage({super.key});

  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  int _days = 3;
  int _duration = 60;
  TrainingExperience _experience = TrainingExperience.starting;
  Set<TrainingEquipment> _equipment = {TrainingEquipment.none};
  bool _requiresProfessionalReview = false;
  bool _hydrated = false;

  void _hydrate(TrainingPreferences? preferences) {
    if (_hydrated) return;
    _hydrated = true;
    if (preferences == null) return;
    _days = preferences.availableDaysPerWeek;
    _duration = preferences.sessionDurationMinutes;
    _experience = preferences.experience;
    _equipment = {...preferences.equipment};
    _requiresProfessionalReview = preferences.requiresProfessionalReview;
  }

  void _toggleEquipment(TrainingEquipment item, bool selected) {
    setState(() {
      if (item == TrainingEquipment.none) {
        _equipment = selected ? {TrainingEquipment.none} : {};
        return;
      }
      _equipment.remove(TrainingEquipment.none);
      selected ? _equipment.add(item) : _equipment.remove(item);
      if (_equipment.isEmpty) _equipment.add(TrainingEquipment.none);
    });
  }

  void _save() {
    context.read<TrainingPreferencesCubit>().save(
      TrainingPreferences(
        availableDaysPerWeek: _days,
        sessionDurationMinutes: _duration,
        experience: _experience,
        equipment: _equipment,
        requiresProfessionalReview: _requiresProfessionalReview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mi plan'),
      ),
      body: BlocConsumer<TrainingPreferencesCubit, TrainingPreferencesState>(
        listener: (context, state) {
          if (state.status == TrainingPreferencesStatus.saved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disponibilidad guardada.')),
            );
          } else if (state.status == TrainingPreferencesStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Ha ocurrido un error.'),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == TrainingPreferencesStatus.loading ||
              state.status == TrainingPreferencesStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          _hydrate(state.preferences);
          final saving = state.status == TrainingPreferencesStatus.saving;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _IntroductionCard(),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF141414),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.flag_outlined,
                            color: Color(0xFFFF8A50),
                          ),
                          title: const Text('Objetivo de preparación'),
                          subtitle: const Text(
                            'Programa de preparación y fecha prevista.',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/plan/goal'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF141414),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.fitness_center_rounded,
                            color: Color(0xFFFF8A50),
                          ),
                          title: const Text('Primera sesión real'),
                          subtitle: const Text(
                            'Bloques, ejercicios, series y descansos cargados desde Supabase.',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/plan/starter-session'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _QuestionCard(
                        title: '¿Cuántos días puedes entrenar cada semana?',
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _days.toDouble(),
                                min: 1,
                                max: 7,
                                divisions: 6,
                                label: '$_days',
                                onChanged: (value) =>
                                    setState(() => _days = value.round()),
                              ),
                            ),
                            SizedBox(
                              width: 74,
                              child: Text(
                                '$_days ${_days == 1 ? 'día' : 'días'}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _QuestionCard(
                        title: '¿Cuánto puede durar una sesión normal?',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [30, 45, 60, 75, 90]
                              .map(
                                (minutes) => ChoiceChip(
                                  label: Text('$minutes min'),
                                  selected: _duration == minutes,
                                  onSelected: (_) =>
                                      setState(() => _duration = minutes),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      _QuestionCard(
                        title: '¿Qué continuidad has tenido entrenando?',
                        child: RadioGroup<TrainingExperience>(
                          groupValue: _experience,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _experience = value);
                            }
                          },
                          child: Column(
                            children: TrainingExperience.values
                                .map(
                                  (experience) => RadioListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: experience,
                                    title: Text(experience.label),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                      _QuestionCard(
                        title: '¿Qué material tienes disponible normalmente?',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TrainingEquipment.values
                              .map(
                                (item) => FilterChip(
                                  label: Text(item.label),
                                  selected: _equipment.contains(item),
                                  onSelected: (selected) =>
                                      _toggleEquipment(item, selected),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      _QuestionCard(
                        title: 'Antes de planificar',
                        subtitle:
                            'No necesitamos que escribas diagnósticos ni datos médicos.',
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _requiresProfessionalReview,
                          title: const Text(
                            'Tengo una lesión, limitación o indicación profesional que debe revisarse',
                          ),
                          subtitle: const Text(
                            'Al marcarlo, la futura planificación automática quedará bloqueada hasta una revisión.',
                          ),
                          onChanged: (value) => setState(
                            () => _requiresProfessionalReview = value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Guardando…' : 'Guardar disponibilidad',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Estos datos aún no generan una rutina. Los usaremos cuando las reglas deportivas estén validadas y probadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFFFF8A50), size: 34),
            SizedBox(height: 14),
            Text(
              'Haz que el futuro plan encaje en tu vida',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Una planificación útil parte del tiempo y los medios que realmente tienes, no de una semana ideal.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF141414),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(color: Colors.white60)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

extension on TrainingExperience {
  String get label => switch (this) {
    TrainingExperience.starting => 'Estoy empezando o llevo tiempo parado',
    TrainingExperience.occasional => 'Entreno de forma ocasional',
    TrainingExperience.consistent => 'Entreno con continuidad',
  };
}

extension on TrainingEquipment {
  String get label => switch (this) {
    TrainingEquipment.none => 'Sin material',
    TrainingEquipment.pullUpBar => 'Barra de dominadas',
    TrainingEquipment.freeWeights => 'Pesas',
    TrainingEquipment.gym => 'Gimnasio',
    TrainingEquipment.runningTrack => 'Pista o zona medida',
  };
}
