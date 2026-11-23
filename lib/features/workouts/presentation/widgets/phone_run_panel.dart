import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/running_step.dart';

import '../../domain/entities/workout_execution.dart';
import '../../domain/services/phone_run_plan.dart';
import '../../domain/services/phone_running.dart';
import '../bloc/phone_run_cubit.dart';
import 'workout_execution_labels.dart';

bool get phoneRunSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class PhoneRunPanel extends StatefulWidget {
  const PhoneRunPanel({
    required this.createRecorder,
    required this.set,
    required this.onSave,
    required this.onManual,
    this.steps = const [],
    this.onGuidedResults,
    super.key,
  });

  final PhoneRunCubit Function() createRecorder;
  final WorkoutExecutionSet set;
  final Future<bool> Function(WorkoutSetResultInput) onSave;
  final Future<void> Function(PhoneRunTotals) onManual;
  final List<PhoneRunStep> steps;
  final Future<bool> Function(List<PhoneRunLap>, PhoneRunLap?)? onGuidedResults;

  @override
  State<PhoneRunPanel> createState() => PhoneRunPanelState();
}

class PhoneRunPanelState extends State<PhoneRunPanel> {
  late final PhoneRunCubit _recorder;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _recorder = widget.createRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _recorder.open(
            steps: widget.steps,
            softGoalSeconds: widget.set.targetDurationSeconds,
          ),
        );
      }
    });
  }

  Future<void> pause() => _recorder.pause();

  @override
  void dispose() {
    unawaited(_recorder.close());
    super.dispose();
  }

  Future<void> _save(PhoneRunTotals totals) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await widget.onSave(
        WorkoutSetResultInput(
          resultId: widget.set.id,
          actualDurationSeconds: totals.seconds,
          actualDistanceMeters: totals.distanceMeters.roundToDouble(),
        ),
      );
      if (saved) {
        await _recorder.clearCheckpoint();
      } else {
        _saveError = 'No se ha podido guardar el rodaje. Puedes reintentar.';
      }
    } catch (_) {
      _saveError = 'Revisa el resultado antes de volver a guardarlo.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manual() async {
    setState(() => _saving = true);
    try {
      await pause();
      if (!mounted) return;
      final onGuidedResults = widget.onGuidedResults;
      if (onGuidedResults == null) {
        await widget.onManual(_recorder.state.totals);
      } else if (await onGuidedResults(_recorder.laps, _recorder.partial)) {
        await _recorder.clearCheckpoint().catchError((Object _) {});
      } else {
        _saveError =
            'No se han podido trasladar los parciales. Puedes reintentar.';
      }
    } catch (_) {
      _saveError =
          'No se han podido trasladar los parciales. Puedes reintentar.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<PhoneRunCubit, PhoneRunState>(
    bloc: _recorder,
    builder: (context, state) {
      final totals = state.totals;
      final review = state.phase == PhoneRunPhase.review;
      final gotDistance = totals.distanceMeters > 0;
      final canSave =
          totals.seconds > 0 &&
          totals.distanceMeters >= 1 &&
          totals.distanceReliable;
      final pace = totals.paceSecondsPerKm;
      final recent = state.recentPace;
      final guided = widget.steps.isNotEmpty;
      final step = state.step;
      final busy = state.busy || _saving;
      final theme = Theme.of(context);
      final distance = NumberFormat.decimalPatternDigits(
        locale: Localizations.localeOf(context).toString(),
        decimalDigits: 2,
      ).format(totals.distanceMeters / 1000);
      final target = widget.set.targetDurationSeconds;
      final targetFast = widget.set.targetPaceMinSecondsPerKm;
      final targetSlow = widget.set.targetPaceMaxSecondsPerKm;
      final status = switch (state.phase) {
        PhoneRunPhase.loading => 'Preparando grabación…',
        PhoneRunPhase.acquiring => 'Buscando señal GPS…',
        PhoneRunPhase.recording when state.signalLost => 'Sin señal GPS',
        PhoneRunPhase.recording => 'Grabando · puedes bloquear la pantalla',
        PhoneRunPhase.stopping => 'Deteniendo GPS…',
        PhoneRunPhase.paused => 'Grabación en pausa',
        PhoneRunPhase.review => 'Grabación detenida',
        PhoneRunPhase.idle => 'Grabación con el móvil',
      };
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(status, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            workoutClock(totals.seconds),
            style: theme.textTheme.displayMedium,
          ),
          Text(
            !guided && target != null
                ? 'Tiempo activo · objetivo ${workoutClock(target)}'
                : 'Tiempo del tramo',
          ),
          if (guided && step != null) ...[
            const SizedBox(height: 12),
            Text(
              '${step.kind.label} · ${state.stepNumber} de ${state.stepCount}',
              style: theme.textTheme.titleLarge,
            ),
            Text(switch (step.completion) {
              RunningStepCompletion.time =>
                '${workoutClock((step.seconds! - totals.seconds).clamp(0, step.seconds!))} restantes',
              RunningStepCompletion.distance =>
                '${totals.distanceMeters.round()} / ${step.meters!.round()} m',
              RunningStepCompletion.manual => 'Hasta marcar vuelta',
            }),
            if (state.nextStep case final next?)
              Text('Después · ${next.kind.label}'),
          ],
          if (!guided && targetFast != null && targetSlow != null)
            Text(
              'Ritmo orientativo · ${workoutClock(targetFast)}–${workoutClock(targetSlow)} min/km',
            ),
          const SizedBox(height: 16),
          Text(
            guided
                ? '${NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toString(), decimalDigits: 2).format(state.sessionDistanceMeters / 1000)} km en la sesión'
                : gotDistance
                ? '$distance km${totals.distanceReliable ? '' : ' · lectura parcial'}'
                : 'Distancia pendiente',
          ),
          Text(
            recent == null
                ? 'Ritmo reciente · —'
                : '${workoutClock(recent)} min/km · ritmo reciente',
            style: theme.textTheme.titleMedium,
          ),
          if (pace != null) Text('${workoutClock(pace)} min/km de media'),
          if (!totals.distanceReliable) ...[
            const SizedBox(height: 8),
            const Text(
              'Falta señal en parte de la carrera. Puedes usar el tiempo y añadir una distancia conocida en el registro manual.',
            ),
          ],
          if (!guided && review && !gotDistance && totals.distanceReliable)
            const Text(
              'Hace falta una distancia medida para guardar en esta pauta.',
            ),
          if ((_saveError ?? state.message) case final message?) ...[
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          if (guided && review)
            FilledButton.icon(
              onPressed: busy ? null : _manual,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Revisar parciales'),
            )
          else if (review && canSave)
            FilledButton(
              onPressed: busy ? null : () => _save(totals),
              child: Text(
                _saving ? 'Guardando…' : 'Guardar y registrar esfuerzo',
              ),
            )
          else if (state.tracking)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : step != null && state.phase == PhoneRunPhase.recording
                  ? () => _recorder.markLap(step.id)
                  : pause,
              icon: Icon(
                step != null && state.phase == PhoneRunPhase.recording
                    ? Icons.flag_outlined
                    : Icons.pause_rounded,
              ),
              label: Text(
                step != null && state.phase == PhoneRunPhase.recording
                    ? 'Marcar vuelta'
                    : 'Pausar',
              ),
            )
          else
            FilledButton.icon(
              onPressed: busy ? null : _recorder.start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                state.phase == PhoneRunPhase.paused
                    ? 'Reanudar'
                    : guided
                    ? 'Empezar entrenamiento'
                    : 'Iniciar GPS',
              ),
            ),
          if (guided &&
              step != null &&
              state.phase == PhoneRunPhase.recording) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : pause,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pausar'),
            ),
          ],
          if (!review &&
              (state.tracking ||
                  totals.seconds > 0 ||
                  _recorder.laps.isNotEmpty)) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : _recorder.review,
              child: const Text('Terminar grabación'),
            ),
          ],
          const SizedBox(height: 8),
          if (!guided || !review)
            TextButton(
              onPressed: busy ? null : _manual,
              child: Text(
                totals.seconds > 0
                    ? 'Usar el registro manual'
                    : 'Volver al registro manual',
              ),
            ),
          if (!review) ...[
            if (guided && !state.tracking)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.trackMode,
                onChanged: busy
                    ? null
                    : (value) => _recorder.configure(trackMode: value),
                title: const Text('Pista · marcar la vuelta'),
                subtitle: const Text(
                  'Los tramos por distancia esperan tu pulsación.',
                ),
              ),
            DropdownButtonFormField<PhoneRunVoice>(
              key: ValueKey(state.voice),
              initialValue: state.voice,
              decoration: const InputDecoration(labelText: 'Avisos de voz'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: PhoneRunVoice.off,
                  child: Text('Sin voz'),
                ),
                if (guided)
                  const DropdownMenuItem(
                    value: PhoneRunVoice.series,
                    child: Text('Final de serie'),
                  ),
                DropdownMenuItem(
                  value: PhoneRunVoice.splits,
                  child: Text(
                    guided ? 'Parciales y final de serie' : 'Cada kilómetro',
                  ),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => _recorder.configure(voice: value),
            ),
            if (guided && widget.steps.any((step) => step.fastestPace != null))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.paceAlerts,
                onChanged: busy
                    ? null
                    : (value) => _recorder.configure(paceAlerts: value),
                title: const Text('Avisar si me salgo del ritmo objetivo'),
              ),
          ],
        ],
      );
    },
  );
}
