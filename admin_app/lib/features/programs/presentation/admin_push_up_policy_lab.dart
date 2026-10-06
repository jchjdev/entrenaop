import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/push_up_performance_proposal.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart';

/// Revisión de reglas con entradas simuladas, separada de los datos del atleta.
class AdminPushUpPolicyLab extends StatefulWidget {
  const AdminPushUpPolicyLab({super.key, required this.repository});
  final AdminExerciseRepository repository;
  @override
  State<AdminPushUpPolicyLab> createState() => _AdminPushUpPolicyLabState();
}

class _AdminPushUpPolicyLabState extends State<AdminPushUpPolicyLab> {
  var _formKey = GlobalKey<FormState>();
  final _resultKey = GlobalKey();
  final _reps = TextEditingController();
  final _minutes = TextEditingController(text: '20');
  final _reservedMinutes = TextEditingController(text: '0');
  final _supportHeight = TextEditingController();
  late Future<List<AdminCatalogExercise>> _catalog;
  double? _rir;
  String _variant = 'push_up_standard';
  String _response = 'initial';
  bool _supportAvailable = false;
  bool _contextConfirmed = false;
  bool _symptoms = false;
  bool _timed = false;
  final Set<int> _days = {0, 3};
  StrengthTrainingDecision? _decision;
  PerformancePreparationPreview? _preview;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.listOfficial();
  }

  @override
  void dispose() {
    _reps.dispose();
    _minutes.dispose();
    _reservedMinutes.dispose();
    _supportHeight.dispose();
    super.dispose();
  }

  void _invalidate() => setState(() => _decision = null);

  void _loadExample(List<AdminCatalogExercise> exercises) {
    // Sustituye solo las entradas ficticias; no registra capacidad del atleta.
    setState(() {
      _reps.text = '8';
      _minutes.text = '20';
      _reservedMinutes.text = '0';
      _supportHeight.clear();
      _rir = 3;
      _variant = 'push_up_standard';
      _response = 'initial';
      _supportAvailable = false;
      _contextConfirmed = true;
      _symptoms = false;
      _timed = false;
      _days
        ..clear()
        ..addAll({0, 3});
      _decision = null;
      // Recrea los campos para mostrar también las selecciones del ejemplo.
      _formKey = GlobalKey<FormState>();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculate(exercises);
    });
  }

  void _calculate(List<AdminCatalogExercise> exercises) {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos señalados antes de calcular.'),
        ),
      );
      return;
    }
    final now = DateTime.now().toUtc();
    final goal = StrengthTask(
      exerciseCode: 'push_up_standard',
      exerciseVersion: 1,
      protocolKey: 'lab_standard_practice',
      protocolVersion: 1,
      setupKey: 'lab_standard',
      measurement: _timed
          ? StrengthMeasurement.repsInTime
          : StrengthMeasurement.reps,
    );
    final task = _variant == 'push_up_standard' && !_timed
        ? goal
        : StrengthTask(
            exerciseCode: _variant,
            exerciseVersion: 1,
            protocolKey: 'lab_untimed_practice',
            protocolVersion: 1,
            setupKey: _variant == 'push_up_incline'
                ? 'support_cm_${int.parse(_supportHeight.text)}'
                : 'lab_standard',
            measurement: StrengthMeasurement.reps,
          );
    final reps = int.parse(_reps.text);
    final prior = StrengthWorkPrescription(
      policyVersion: PushUpRepetitionsPolicy.version,
      goal: goal,
      task: task,
      setCount: 2,
      repsPerSet: reps,
      targetRir: 3,
      restSeconds: 120,
    );
    final exposures = <StrengthExposure>[];
    if (_response != 'initial') {
      final count = _response == 'one_good' ? 1 : 2;
      for (var i = 0; i < count; i++) {
        exposures.add(
          StrengthExposure(
            id: 'simulated_$i',
            performedOn: now.subtract(Duration(days: 2 + i * 3)),
            prescription: prior,
            interruption: _response == 'time'
                ? StrengthInterruption.time
                : StrengthInterruption.none,
            sets: [
              for (var s = 0; s < 2; s++)
                StrengthSetObservation(
                  validReps: reps,
                  techniqueValid: true,
                  reportedRir: _response == 'missing'
                      ? null
                      : _response == 'difficult'
                      ? 1
                      : 3,
                ),
            ],
          ),
        );
      }
    }
    final decision = PushUpRepetitionsPolicy().preview(
      goal: goal,
      catalog: exercises
          .map((e) => e.trainingProfile)
          .whereType<StrengthExerciseDefinition>(),
      equipment: {if (_supportAvailable) 'stable_support'},
      references: [
        if (_rir != null)
          StrengthWorkingReference(
            task: task,
            validReps: reps,
            reportedRir: _rir!,
            observedOn: now.subtract(const Duration(days: 10)),
            currentCapacityConfirmed: _contextConfirmed,
          ),
      ],
      slots: [
        for (final day in _days)
          StrengthDaySlot(
            day: day,
            availableSeconds: int.parse(_minutes.text) * 60,
            reservedSeconds: int.parse(_reservedMinutes.text) * 60,
          ),
      ],
      now: now,
      currentContextConfirmed: _contextConfirmed,
      hasSymptoms: _symptoms,
      previousPrescription: _response == 'initial' ? null : prior,
      history: exposures,
    );
    final objective = PerformanceTrainingGoal(
      id: 'lab_push_up_goal',
      capability: _timed
          ? PerformanceCapability.repetitionsInTime
          : PerformanceCapability.repetitions,
      questionBlock: PerformanceQuestionBlock.pushes,
      task: goal,
      loadMode: StrengthLoadMode.bodyweight,
    );
    final preview = PerformancePreparationPreview(
      goals: [objective],
      proposals: [
        pushUpPerformanceProposal(goal: objective, decision: decision),
      ],
    );
    setState(() {
      _decision = decision;
      _preview = preview;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultContext = _resultKey.currentContext;
      if (mounted && resultContext != null) {
        Scrollable.ensureVisible(
          resultContext,
          alignment: 0.1,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<AdminCatalogExercise>>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () =>
              setState(() => _catalog = widget.repository.listOfficial()),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar catálogo'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      if (!snapshot.data!.any(
        (e) =>
            e.trainingProfile?.code == 'push_up_standard' &&
            e.trainingProfile?.definitionVersion == 1,
      )) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se puede calcular: falta el perfil oficial de flexión estándar v1 '
              'en la biblioteca recibida. Revisa la carga del catálogo y sus permisos.',
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _catalog = widget.repository.listOfficial()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar catálogo'),
            ),
          ],
        );
      }
      return Form(
        key: _formKey,
        onChanged: _invalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simula la preparación de flexiones máximas sin límite de tiempo. '
              'Las entradas son ficticias y la propuesta no se guarda en programas ni agendas. '
              'La dosis está pendiente de revisión deportiva.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _loadExample(snapshot.data!),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Cargar ejemplo y calcular'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'El ejemplo sustituye estos campos por datos ficticios: '
                '8 repeticiones, RIR 3, 20 minutos y lunes/jueves. No se guarda.',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _variant,
              decoration: const InputDecoration(
                labelText: 'Variante de la referencia de trabajo',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'push_up_standard',
                  child: Text('Flexión estándar'),
                ),
                DropdownMenuItem(
                  value: 'push_up_incline',
                  child: Text('Flexión inclinada'),
                ),
              ],
              onChanged: (v) => setState(() {
                _variant = v!;
                _decision = null;
              }),
            ),
            if (_variant == 'push_up_incline') ...[
              TextFormField(
                controller: _supportHeight,
                decoration: const InputDecoration(
                  labelText: 'Altura del apoyo (cm)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'Identifica la altura del apoyo.',
              ),
              SwitchListTile(
                title: const Text('Tiene un apoyo estable a esa altura'),
                value: _supportAvailable,
                onChanged: (v) => setState(() {
                  _supportAvailable = v;
                  _decision = null;
                }),
              ),
            ],
            TextFormField(
              controller: _reps,
              decoration: const InputDecoration(
                labelText: 'Repeticiones válidas de una serie de trabajo',
                helperText: 'No es la marca máxima del examen. Conserva el mismo montaje y técnica.',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                  ? null
                  : 'Introduce una serie válida positiva.',
            ),
            DropdownButtonFormField<double>(
              initialValue: _rir,
              decoration: const InputDecoration(
                labelText: 'RIR declarado en esa serie',
                helperText: 'Este ensayo requiere RIR 2–4 para calibrar; otros valores no generan dosis.',
              ),
              hint: const Text('Sin dato'),
              items: [
                for (var i = 0; i <= 10; i++)
                  DropdownMenuItem(value: i.toDouble(), child: Text('$i')),
              ],
              onChanged: (v) => setState(() {
                _rir = v;
                _decision = null;
              }),
            ),
            TextFormField(
              controller: _minutes,
              decoration: const InputDecoration(
                labelText: 'Minutos disponibles por día',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v ?? '') ?? -1) >= 0
                  ? null
                  : 'Introduce minutos enteros no negativos.',
            ),
            TextFormField(
              controller: _reservedMinutes,
              decoration: const InputDecoration(
                labelText: 'Minutos reservados para otras tareas por día',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final reserved = int.tryParse(v ?? '');
                final available = int.tryParse(_minutes.text);
                return reserved != null &&
                        available != null &&
                        reserved >= 0 &&
                        reserved <= available
                    ? null
                    : 'La reserva debe caber en el tiempo disponible.';
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(_dayNames[i]),
                    selected: _days.contains(i),
                    onSelected: (selected) => setState(() {
                      selected ? _days.add(i) : _days.remove(i);
                      _decision = null;
                    }),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _response,
              decoration: const InputDecoration(
                labelText: 'Respuesta simulada a la dosis anterior',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'initial',
                  child: Text('Sin dosis anterior'),
                ),
                DropdownMenuItem(
                  value: 'one_good',
                  child: Text('Una ejecución tolerada'),
                ),
                DropdownMenuItem(
                  value: 'good',
                  child: Text('Dos ejecuciones toleradas'),
                ),
                DropdownMenuItem(
                  value: 'difficult',
                  child: Text('Dos ejecuciones con RIR 1'),
                ),
                DropdownMenuItem(
                  value: 'time',
                  child: Text('Interrupciones por falta de tiempo'),
                ),
                DropdownMenuItem(
                  value: 'missing',
                  child: Text('Resultados sin RIR declarado'),
                ),
              ],
              onChanged: (v) => setState(() {
                _response = v!;
                _decision = null;
              }),
            ),
            SwitchListTile(
              title: const Text('Capacidad y contexto actuales confirmados'),
              value: _contextConfirmed,
              onChanged: (v) => setState(() {
                _contextConfirmed = v;
                _decision = null;
              }),
            ),
            SwitchListTile(
              title: const Text('Presenta molestias o limitación'),
              value: _symptoms,
              onChanged: (v) => setState(() {
                _symptoms = v;
                _decision = null;
              }),
            ),
            SwitchListTile(
              title: const Text('La prueba tiene límite de tiempo'),
              value: _timed,
              onChanged: (v) => setState(() {
                _timed = v;
                _decision = null;
              }),
            ),
            FilledButton.icon(
              onPressed: () => _calculate(snapshot.data!),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Calcular propuesta de prueba'),
            ),
            if (_decision case final decision?) ...[
              const SizedBox(height: 16),
              Text(
                _statusLabel(decision.status),
                key: _resultKey,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_preview case final preview?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Objetivos con propuesta para revisar: '
                    '${preview.proposals.length - preview.pending.length}/${preview.goals.length}. '
                    'Política experimental; coordinación y publicación pendientes.',
                  ),
                ),
              for (final session in decision.sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_dayNames[session.day]} · ${_exerciseName(snapshot.data!, session.prescription.task)}',
                  ),
                  subtitle: Text(
                    '${session.prescription.setCount} series × ${session.prescription.repsPerSet} repeticiones · '
                    'objetivo RIR ${session.prescription.targetRir.toInt()} · '
                    '${session.prescription.restSeconds} s entre series\n'
                    'Detener la serie al perder el estándar técnico o alcanzar el esfuerzo previsto. '
                    'Tiempo orientativo: ${(session.prescription.estimatedSeconds / 60).ceil()} min.',
                  ),
                ),
              for (final reason in decision.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_reasonLabel(reason)),
                ),
              const Text(
                'La variante inclinada es apoyo; no equivale a una marca de flexiones estándar. '
                'La agenda de este laboratorio comprueba tiempo y separación; la coordinación completa con carrera sigue pendiente.',
              ),
            ],
          ],
        ),
      );
    },
  );
}

const _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String _exerciseName(List<AdminCatalogExercise> catalog, StrengthTask task) =>
    catalog
        .where(
          (e) =>
              e.trainingProfile?.code == task.exerciseCode &&
              e.trainingProfile?.definitionVersion == task.exerciseVersion,
        )
        .first
        .name;

String _statusLabel(StrengthDecisionStatus status) => switch (status) {
  StrengthDecisionStatus.ready => 'Propuesta para revisión',
  StrengthDecisionStatus.needsContext => 'Falta confirmar el contexto',
  StrengthDecisionStatus.needsCalibration =>
    'Hace falta calibrar una variante accesible',
  StrengthDecisionStatus.blocked => 'No se propone entrenamiento con molestias',
  StrengthDecisionStatus.unsupported => 'Este objetivo aún no está cubierto',
  StrengthDecisionStatus.noSpace => 'La propuesta no cabe en la agenda',
};

String _reasonLabel(StrengthDecisionReason reason) => switch (reason) {
  StrengthDecisionReason.symptoms =>
    'Revisa la molestia o limitación antes de continuar.',
  StrengthDecisionReason.contextMissing =>
    'La referencia debe representar la situación actual.',
  StrengthDecisionReason.unsupportedGoal => 'Esta estrategia cubre flexiones estándar máximas sin ventana temporal. No convierte otros protocolos en equivalentes.',
  StrengthDecisionReason.calibrationMissing => 'Falta una serie válida comparable con RIR 2–4 y material confirmado. No deducimos la dosis del máximo del examen.',
  StrengthDecisionReason.specificPractice =>
    'Se prioriza la variante y el protocolo del objetivo.',
  StrengthDecisionReason.accessibleSupport => 'Se usa una variante inclinada calibrada como apoyo accesible. La práctica estándar queda por incorporar.',
  StrengthDecisionReason.initialDose => 'Inicio provisional: dos series de la variante calibrada, hasta dos días semanales.',
  StrengthDecisionReason.comparableHistoryMissing => 'Sin ejecuciones comparables de esta dosis: se mantiene y se pide registro.',
  StrengthDecisionReason.twoToleratedExposures => 'Dos ejecuciones completas, válidas y con margen: se añade una repetición por serie.',
  StrengthDecisionReason.twoDifficultExposures => 'Dos ejecuciones difíciles: se retira una repetición por serie, conservando descanso y series.',
  StrengthDecisionReason.responseUnclear => 'La respuesta no permite progresar. Revisa esfuerzo, técnica y motivo de interrupción.',
  StrengthDecisionReason.oneExposureOnly =>
    'Una sola ejecución no basta para cambiar la dosis.',
  StrengthDecisionReason.recalibrationRequired =>
    'La referencia o dosis ya no es aplicable; hay que recalibrar.',
  StrengthDecisionReason.agendaLimited =>
    'Solo cabe una exposición separada en esta semana.',
  StrengthDecisionReason.noAvailableSlot => 'El tiempo reservado para otras tareas y las restricciones dejan la propuesta sin hueco.',
};
