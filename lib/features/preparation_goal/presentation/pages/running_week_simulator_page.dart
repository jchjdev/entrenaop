import 'package:entrenaop/features/preparation_goal/data/initial_week_draft_catalog.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/initial_running_week_planner.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Banco de pruebas local: reutiliza la decisión de dominio sin escribir en
/// Supabase ni convertir el borrador deportivo en sesiones oficiales.
class RunningWeekSimulatorPage extends StatefulWidget {
  const RunningWeekSimulatorPage({
    super.key,
    required this.goalId,
    required this.loadRunningTests,
    required this.loadPreferences,
    this.draft,
  });

  final String goalId;
  final Future<List<RunningTestResult>> Function(String goalId)
  loadRunningTests;
  final Future<TrainingPreferences?> Function() loadPreferences;
  final Future<InitialWeekDraft>? draft;

  @override
  State<RunningWeekSimulatorPage> createState() =>
      _RunningWeekSimulatorPageState();
}

class _RunningWeekSimulatorPageState extends State<RunningWeekSimulatorPage> {
  static const _planner = InitialRunningWeekPlanner();

  late final Future<InitialWeekDraft> _draft =
      widget.draft ?? InitialWeekDraftCatalog.load();
  late final Future<void> _savedInputs = _loadSavedInputs();
  final _testTime = TextEditingController();
  final _scrollController = ScrollController();
  int _totalDays = 3;
  int _runningDays = 2;
  int _recentRunningDays = -1;
  int _sessionMinutes = 45;
  bool _reportsPain = false;
  bool _requiresReview = false;
  bool _hasOfficialWeek = false;
  InitialRunningWeekDecision? _decision;
  String _testSource = 'Sin test de 2 km guardado para esta preparación.';
  String _preferencesSource = 'Sin preferencias guardadas; revisa los valores.';
  bool _sourceLoadFailed = false;
  bool _inputsReady = false;

  int get _strengthDays => _totalDays - _runningDays;

  Future<void> _loadSavedInputs() async {
    // Las dos lecturas son independientes: un fallo no debe ocultar la otra.
    final testsFuture = _latestTest();
    final preferencesFuture = _savedPreferences();
    final test = await testsFuture;
    final preferences = await preferencesFuture;
    if (!mounted) return;
    if (preferences != null) {
      _totalDays = preferences.availableDaysPerWeek.clamp(1, 7);
      _runningDays = _runningDays.clamp(1, _totalDays);
      if (preferences.sessionDurationMinutes > 0) {
        _sessionMinutes = preferences.sessionDurationMinutes;
      }
      _requiresReview = preferences.requiresProfessionalReview;
      _preferencesSource =
          'De tus preferencias guardadas. El reparto entre carrera y fuerza sigue siendo provisional.';
    }
    if (test != null) {
      final minutes = test.durationSeconds ~/ 60;
      final seconds = (test.durationSeconds % 60).toString().padLeft(2, '0');
      _testTime.text = '$minutes:$seconds';
      final date = test.completedAt;
      _testSource =
          'Del test de 2 km del ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}. Comprueba si sigue siendo representativo.';
    }
    setState(() => _inputsReady = true);
  }

  Future<RunningTestResult?> _latestTest() async {
    try {
      final tests = await widget.loadRunningTests(widget.goalId);
      return tests.firstOrNull;
    } catch (_) {
      _sourceLoadFailed = true;
      _testSource =
          'No se pudo consultar el test; introduce la marca manualmente.';
      return null;
    }
  }

  Future<TrainingPreferences?> _savedPreferences() async {
    try {
      return await widget.loadPreferences();
    } catch (_) {
      _sourceLoadFailed = true;
      _preferencesSource =
          'No se pudieron consultar las preferencias; revisa los valores.';
      return null;
    }
  }

  @override
  void dispose() {
    _testTime.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _useExample() {
    setState(() {
      _totalDays = 3;
      _runningDays = 2;
      _recentRunningDays = 2;
      _sessionMinutes = 45;
      _testTime.text = '10:00';
      _reportsPain = false;
      _requiresReview = false;
      _hasOfficialWeek = false;
      _decision = null;
      _testSource = 'Ejemplo ficticio; no procede de tu test.';
      _preferencesSource = 'Ejemplo ficticio; no modifica tus preferencias.';
    });
  }

  void _simulate() {
    final input = InitialRunningWeekInput(
      programId: PreparationProgramIds.armedForcesTroopEntry,
      totalTrainingDaysPerWeek: _totalDays,
      runningDaysPerWeek: _runningDays,
      allocatedStrengthDaysPerWeek: _strengthDays,
      combinedDaysPerWeek: 0,
      recentRunningDaysPerWeek: _recentRunningDays < 0
          ? null
          : _recentRunningDays,
      sessionDurationMinutes: _sessionMinutes,
      reference2kSeconds: parseDurationInput(_testTime.text),
      reportsPain: _reportsPain,
      requiresProfessionalReview: _requiresReview,
      alreadyHasOfficialRunningWeek: _hasOfficialWeek,
    );
    setState(() => _decision = _planner.plan(input));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Simulador · Tropa'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          onPressed: _inputsReady ? _simulate : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Simular semana'),
        ),
      ),
      body: FutureBuilder<void>(
        future: _savedInputs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<InitialWeekDraft>(
            future: _draft,
            builder: (context, draftSnapshot) {
              if (draftSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (draftSnapshot.hasError || draftSnapshot.data == null) {
                return const Center(
                  child: Text('No se ha podido cargar el borrador deportivo.'),
                );
              }
              return _body(draftSnapshot.data!);
            },
          );
        },
      ),
    );
  }

  Widget _body(InitialWeekDraft draft) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Prueba una primera semana',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cargamos tu último test de 2 km y tus preferencias si existen. Puedes cambiarlos aquí para probar escenarios: nada se guarda ni se añade a la agenda.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                if (_sourceLoadFailed) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No se pudieron cargar todos tus datos. Revisa los valores antes de simular.',
                    style: TextStyle(color: Color(0xFFFFA477)),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Límite actual: la marca solo comprueba que existe; todavía no calcula ritmos. El tiempo disponible solo comprueba un mínimo, no ajusta los tramos.',
                  style: TextStyle(color: Color(0xFFFFA477), height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _useExample,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('Usar ejemplo ficticio'),
                ),
                if (_decision != null) ...[
                  const SizedBox(height: 16),
                  _result(draft, _decision!),
                ],
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF171717),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Disponibilidad conjunta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Los días de carrera y fuerza comparten el total. Aquí no se mezclan en un mismo día.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 18),
                        _numberField(
                          label: 'Días totales por semana',
                          value: _totalDays,
                          values: List.generate(7, (index) => index + 1),
                          onChanged: (value) => setState(() {
                            _totalDays = value;
                            if (_runningDays > value) _runningDays = value;
                            _preferencesSource =
                                'Modificado para esta simulación; no se guarda.';
                            _decision = null;
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _preferencesSource,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 12),
                        _numberField(
                          label: 'Días asignados a carrera',
                          value: _runningDays,
                          values: List.generate(
                            _totalDays < 4 ? _totalDays : 4,
                            (index) => index + 1,
                          ),
                          onChanged: (value) => setState(() {
                            _runningDays = value;
                            _decision = null;
                          }),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Quedan $_strengthDays días para fuerza.',
                          style: const TextStyle(color: Color(0xFFFFA477)),
                        ),
                        const SizedBox(height: 16),
                        _numberField(
                          label: 'Días de carrera recientes por semana',
                          value: _recentRunningDays,
                          values: List.generate(9, (index) => index - 1),
                          labelFor: (value) =>
                              value < 0 ? 'Sin indicar' : '$value días',
                          onChanged: (value) => setState(() {
                            _recentRunningDays = value;
                            _decision = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _numberField(
                          label: 'Tiempo disponible por sesión',
                          value: _sessionMinutes,
                          values: {
                            ...[20, 30, 45, 60, 90],
                            _sessionMinutes,
                          }.toList()..sort(),
                          labelFor: (value) => '$value min',
                          onChanged: (value) => setState(() {
                            _sessionMinutes = value;
                            _preferencesSource =
                                'Modificado para esta simulación; no se guarda.';
                            _decision = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _testTime,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [DurationInputFormatter()],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Marca de 2 km (escenario)',
                            hintText: 'Ejemplo: 10:00',
                            helperText:
                                'Puedes escribir solo dígitos: 1000 → 10:00.',
                          ),
                          onChanged: (_) => setState(() {
                            _testSource =
                                'Modificado para esta simulación; no se guarda.';
                            _decision = null;
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _testSource,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Dolor o posible lesión'),
                          value: _reportsPain,
                          onChanged: (value) => setState(() {
                            _reportsPain = value;
                            _decision = null;
                          }),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Revisión profesional pendiente'),
                          value: _requiresReview,
                          onChanged: (value) => setState(() {
                            _requiresReview = value;
                            _preferencesSource =
                                'Modificado para esta simulación; no se guarda.';
                            _decision = null;
                          }),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Ya existe semana oficial de carrera',
                          ),
                          value: _hasOfficialWeek,
                          onChanged: (value) => setState(() {
                            _hasOfficialWeek = value;
                            _decision = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
    String Function(int)? labelFor,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem(
            value: item,
            child: Text(labelFor?.call(item) ?? '$item días'),
          ),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  Widget _result(InitialWeekDraft draft, InitialRunningWeekDecision decision) {
    if (!decision.canPropose) {
      return Card(
        color: const Color(0xFF2A1C19),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Todavía no podemos proponer esta semana',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final blocker in decision.blockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${_blockerLabel(blocker)}'),
                ),
              if (decision.blockers.contains(RunningWeekBlocker.healthReview))
                const Text(
                  'Ante dolor o posible lesión, consulta con fisioterapia o medicina deportiva antes de aumentar la carga.',
                  style: TextStyle(color: Color(0xFFFFA477), height: 1.4),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF17211B),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Propuesta de prueba · no asignada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Reglas: ${decision.version} · contenido: ${draft.version}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final kind in decision.sessions)
              _simulationSession(draft, kind),
            if (_strengthDays > 0) _simulationStrength(draft, _strengthDays),
            const SizedBox(height: 10),
            const Text(
              'Por qué sale esta propuesta',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final reason in decision.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('• ${_reasonLabel(reason)}'),
              ),
            const SizedBox(height: 8),
            const Text(
              'Son componentes, no fechas. Ritmos, minutos, fuerza concreta, segunda semana, descarga y coordinación con otros planes siguen pendientes. Esta propuesta no se puede ejecutar ni registrar.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simulationSession(
    InitialWeekDraft draft,
    RunningWeekSessionKind kind,
  ) {
    final id = switch (kind) {
      RunningWeekSessionKind.controlledQuality => 'controlled_quality',
      RunningWeekSessionKind.easy => 'easy_running',
      RunningWeekSessionKind.recovery => null,
    };
    final template = id == null
        ? null
        : draft.sessions.where((item) => item.id == id).firstOrNull;
    final title = kind == RunningWeekSessionKind.recovery
        ? 'Carrera regenerativa · contenido pendiente'
        : template?.title ?? 'Carrera · contenido pendiente';
    return ExpansionTile(
      title: Text(title),
      subtitle: const Text('Carrera · sin día ni ritmo fijado'),
      children: [
        if (template == null)
          const ListTile(
            title: Text('Esta variante aún no tiene una sesión base revisada.'),
          )
        else
          for (final detail in template.details)
            ListTile(dense: true, title: Text(detail)),
      ],
    );
  }

  Widget _simulationStrength(InitialWeekDraft draft, int days) {
    final template = draft.sessions
        .where((item) => item.id == 'strength')
        .firstOrNull;
    return ExpansionTile(
      title: Text(
        'Fuerza · $days ${days == 1 ? 'día reservado' : 'días reservados'}',
      ),
      subtitle: const Text('Contenido y ubicación pendientes'),
      children: [
        if (template == null)
          const ListTile(title: Text('Sesión base de fuerza pendiente.'))
        else
          for (final detail in template.details)
            ListTile(dense: true, title: Text(detail)),
      ],
    );
  }
}

String _blockerLabel(RunningWeekBlocker blocker) => switch (blocker) {
  RunningWeekBlocker.unsupportedProgram =>
    'Estas reglas solo cubren Tropa y Marinería.',
  RunningWeekBlocker.healthReview =>
    'Hay dolor o una revisión profesional pendiente.',
  RunningWeekBlocker.missingRunningAvailability =>
    'Indica días de carrera e historial reciente.',
  RunningWeekBlocker.missingStrengthAllocation =>
    'Falta reservar días para fuerza.',
  RunningWeekBlocker.invalidRunningDays =>
    'La carrera debe ocupar entre 1 y 4 días en esta versión.',
  RunningWeekBlocker.invalidRunningHistory =>
    'El historial de carrera indicado no es válido.',
  RunningWeekBlocker.invalidProgramAllocation =>
    'El reparto no cabe en los días totales o deja fuerza sin espacio.',
  RunningWeekBlocker.combinedDayNeedsReview =>
    'Los días mixtos de fuerza y carrera aún no están definidos.',
  RunningWeekBlocker.insufficientSessionTime =>
    'Esta versión necesita al menos 30 minutos disponibles por sesión.',
  RunningWeekBlocker.missingRunningReference =>
    'Falta una marca válida de 2 km para este escenario.',
  RunningWeekBlocker.existingOfficialWeek =>
    'Ya hay una semana oficial de carrera: no proponemos otra encima.',
};

String _reasonLabel(RunningWeekReason reason) => switch (reason) {
  RunningWeekReason.oneControlledQuality =>
    'Una sola calidad controlada como norma inicial.',
  RunningWeekReason.buildRunningBase =>
    'Sin base reciente suficiente, solo carrera fácil de familiarización.',
  RunningWeekReason.easyRunningIncluded =>
    'Se incluye carrera fácil para no convertir toda la semana en calidad.',
  RunningWeekReason.limitedRunningFrequency =>
    'Un solo día de carrera limita la preparación específica del 2 km.',
  RunningWeekReason.noThresholdInferredFrom2k =>
    'La marca de 2 km no se interpreta como umbral fisiológico medido.',
};
