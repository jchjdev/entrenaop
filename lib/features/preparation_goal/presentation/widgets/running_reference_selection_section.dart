import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_reuse_policy.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_selection_policy.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RunningReferenceSelectionSection extends StatefulWidget {
  const RunningReferenceSelectionSection({
    required this.goalId,
    required this.candidates,
    required this.context,
    required this.loadState,
    required this.choose,
    required this.clear,
    required this.now,
    super.key,
  });

  final String goalId;
  final List<RunningReferenceCandidate> candidates;
  final RunningInitialContext? context;
  final Future<RunningReferenceSelectionState> Function(String goalId)
  loadState;
  final Future<void> Function({
    required String goalId,
    required RunningReferenceCandidate candidate,
    required bool confirmContinuity,
  })
  choose;
  final Future<void> Function(String goalId) clear;
  final DateTime Function() now;

  @override
  State<RunningReferenceSelectionSection> createState() =>
      _RunningReferenceSelectionSectionState();
}

class _RunningReferenceSelectionSectionState
    extends State<RunningReferenceSelectionSection> {
  late Future<RunningReferenceSelectionState> _state;
  String? _confirmedRecordId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant RunningReferenceSelectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalId != widget.goalId ||
        oldWidget.context?.collectedAt != widget.context?.collectedAt ||
        oldWidget.candidates != widget.candidates) {
      _confirmedRecordId = null;
      _reload();
    }
  }

  void _reload() => _state = widget.loadState(widget.goalId);

  Future<void> _choose(
    RunningReferenceCandidate candidate,
    bool conditional,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.choose(
        goalId: widget.goalId,
        candidate: candidate,
        confirmContinuity: conditional,
      );
      if (mounted) {
        setState(() {
          _confirmedRecordId = null;
          _reload();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo elegir la marca. Revisa la continuidad, las últimas cuatro semanas y las molestias.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.clear(widget.goalId);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo quitar la selección.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referencia para el plan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige una marca de esta preparación. Elegirla no crea ni publica entrenamientos.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<RunningReferenceSelectionState>(
            future: _state,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? const Text('No se pudo cargar la marca elegida.')
                    : const LinearProgressIndicator();
              }
              final selection = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selection.selection == null)
                    const Text('Todavía no has elegido una marca.')
                  else ...[
                    Text(
                      selection.readyForPlanningInput
                          ? 'Marca elegida y contexto actual. Aún falta generar el plan.'
                          : _selectedIssueText(selection),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _clear,
                      child: const Text('Quitar elección'),
                    ),
                  ],
                  for (final candidate in widget.candidates)
                    _candidateRow(candidate, selection.selection),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _candidateRow(
    RunningReferenceCandidate candidate,
    RunningReferenceSelection? selection,
  ) {
    final now = widget.now();
    final assessment = const RunningReferenceReusePolicy().assess(
      measuredAt: candidate.completedAt,
      now: now,
    );
    final conditional =
        assessment.window == RunningReferenceReuseWindow.conditional;
    final enabled =
        assessment.window == RunningReferenceReuseWindow.recent ||
        assessment.window == RunningReferenceReuseWindow.conditional;
    final alreadySelected = selection?.matches(candidate) ?? false;
    final probe = RunningReferenceSelection(
      goalId: widget.goalId,
      source: candidate.source,
      recordId: candidate.recordId,
      selectedAt: now,
      continuityConfirmedAt: conditional ? now : null,
    );
    final conditionalIssues = conditional
        ? const RunningReferenceSelectionPolicy().inspect(
            candidate: candidate,
            selection: probe,
            context: widget.context,
            now: now,
          )
        : const <RunningReferenceSelectionIssue>[];
    final canChoose =
        enabled &&
        !alreadySelected &&
        !_saving &&
        (!conditional ||
            (conditionalIssues.isEmpty &&
                _confirmedRecordId == candidate.recordId));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(switch (candidate.source) {
            RunningReferenceSource.trainingControl =>
              'Control de entrenamiento de 2 km',
            RunningReferenceSource.troopControl =>
              'Control de carrera de Tropa',
            RunningReferenceSource.fasPeriodicAssessment =>
              'Evaluación periódica FAS',
            RunningReferenceSource.troopOfficialAssessment =>
              'Evaluación oficial de Tropa',
            RunningReferenceSource.programAssessment =>
              'Evaluación del programa',
          }),
          Text(
            '2 km · ${_formatSeconds(candidate.durationSeconds)} · '
            '${DateFormat('dd/MM/yyyy').format(candidate.completedAt)}',
          ),
          Text(
            assessment.window == RunningReferenceReuseWindow.recent
                ? 'Dentro de 30 días'
                : assessment.window == RunningReferenceReuseWindow.conditional
                ? 'Día ${assessment.daysOld}: requiere continuidad'
                : 'Fuera de plazo para fijar ritmos',
          ),
          if (conditional && conditionalIssues.isNotEmpty)
            const Text(
              'Actualiza el contexto y revisa las semanas sin carrera o las molestias antes de elegirla.',
            ),
          if (conditional && conditionalIssues.isEmpty && !alreadySelected)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Confirmo que he seguido entrenando carrera con continuidad desde esta prueba',
              ),
              value: _confirmedRecordId == candidate.recordId,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _confirmedRecordId = value == true
                          ? candidate.recordId
                          : null;
                    }),
            ),
          if (alreadySelected)
            const Text('Elegida')
          else if (enabled)
            FilledButton.tonal(
              onPressed: canChoose
                  ? () => _choose(candidate, conditional)
                  : null,
              child: const Text('Elegir esta marca'),
            ),
        ],
      ),
    );
  }
}

String _selectedIssueText(RunningReferenceSelectionState state) {
  if (state.candidate == null) {
    return 'La marca elegida ya no está disponible en esta preparación.';
  }
  if (state.issues.contains(RunningReferenceSelectionIssue.expired)) {
    return 'La marca elegida ya superó los 45 días: registra un control nuevo.';
  }
  if (state.issues.contains(RunningReferenceSelectionIssue.healthReview)) {
    return 'La marca está elegida, pero has indicado molestias o una limitación.';
  }
  if (state.issues.contains(
    RunningReferenceSelectionIssue.interruptedRunning,
  )) {
    return 'La marca está elegida, pero aparece una semana sin carrera: necesita un control nuevo.';
  }
  if (state.issues.contains(
    RunningReferenceSelectionIssue.missingCurrentContext,
  )) {
    return 'La marca está elegida. Actualiza tus últimas cuatro semanas y tu estado actual.';
  }
  if (state.issues.contains(
    RunningReferenceSelectionIssue.continuityNotConfirmed,
  )) {
    return 'La marca está elegida, pero falta confirmar continuidad desde la prueba.';
  }
  return 'La marca elegida necesita revisión antes de pautar.';
}

String _formatSeconds(double seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds - minutes * 60;
  final raw = remainder.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  final clean = raw.endsWith('.') ? raw.substring(0, raw.length - 1) : raw;
  final parts = clean.split('.');
  return '$minutes:${parts.first.padLeft(2, '0')}'
      '${parts.length == 1 ? '' : '.${parts.last}'}';
}
