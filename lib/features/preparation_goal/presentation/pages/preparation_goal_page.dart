import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PreparationGoalPage extends StatefulWidget {
  const PreparationGoalPage({super.key});

  @override
  State<PreparationGoalPage> createState() => _PreparationGoalPageState();
}

class _PreparationGoalPageState extends State<PreparationGoalPage> {
  DateTime? _targetDate;
  bool _hydrated = false;

  void _hydrate(PreparationGoal? goal) {
    if (_hydrated) return;
    _hydrated = true;
    if (goal == null) return;
    _targetDate = goal.targetDate;
  }

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate?.isAfter(today) == true
          ? _targetDate!
          : today.add(const Duration(days: 90)),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: 'Fecha prevista de las pruebas',
    );
    if (date != null) setState(() => _targetDate = date);
  }

  void _save(PreparationGoal? currentGoal) {
    context.read<PreparationGoalCubit>().save(
      PreparationGoal(
        id: currentGoal?.id,
        programId: PreparationProgramIds.armedForcesTroopEntry,
        targetDate: _targetDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Mi objetivo'),
      ),
      body: BlocConsumer<PreparationGoalCubit, PreparationGoalState>(
        listener: (context, state) {
          if (state.status == PreparationGoalStatus.saved) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Objetivo guardado.')));
          } else if (state.status == PreparationGoalStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Ha ocurrido un error.'),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == PreparationGoalStatus.initial ||
              state.status == PreparationGoalStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          _hydrate(state.goal);
          final saving = state.status == PreparationGoalStatus.saving;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Card(
                        color: Color(0xFF171717),
                        child: Padding(
                          padding: EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.military_tech_outlined,
                                color: Color(0xFFFF8A50),
                                size: 36,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Ingreso · Tropa y marinería',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Orden DEF/15/2026 · Catálogo oficial versionado',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        color: const Color(0xFF141414),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Fecha prevista de las pruebas',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Es opcional hasta que conozcas la convocatoria.',
                                style: TextStyle(color: Colors.white60),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _chooseDate,
                                icon: const Icon(Icons.event_outlined),
                                label: Text(
                                  _targetDate == null
                                      ? 'Elegir fecha'
                                      : DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_targetDate!),
                                ),
                              ),
                              if (_targetDate != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _targetDate = null),
                                  child: const Text(
                                    'Todavía no conozco la fecha',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: saving ? null : () => _save(state.goal),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Guardando…' : 'Guardar objetivo'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Añadiremos nuevos programas solo cuando sus pruebas y baremos estén verificados.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
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
