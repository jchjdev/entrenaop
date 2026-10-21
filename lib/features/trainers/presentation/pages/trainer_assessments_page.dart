import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_editor_ui/assessment_capture_fields.dart';

String _error(Object e) => e is FormatException ? e.message : trainerError(e);
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

class TrainerStudentAssessmentsPage extends StatefulWidget {
  const TrainerStudentAssessmentsPage({super.key, required this.repository});
  final ProfessionalAssessmentStudentRepository repository;
  @override
  State<TrainerStudentAssessmentsPage> createState() =>
      _TrainerStudentAssessmentsPageState();
}

class _TrainerStudentAssessmentsPageState
    extends State<TrainerStudentAssessmentsPage> {
  List<ProfessionalAssessmentDelivery> _items = [];
  bool _busy = true, _more = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final rows = await widget.repository.mine(
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pruebas de mi preparador'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        if (!_busy && _items.isEmpty && _message == null)
          const Text('No tienes pruebas asignadas.'),
        for (final item in _items)
          Card(
            child: ListTile(
              title: Text(item.battery.title),
              subtitle: Text(
                '${item.trainerName} · ${item.statusLabel}\nFecha pautada ${_date(item.scheduledDate)}',
              ),
              isThreeLine: true,
              onTap: () async {
                await context.push('/my-trainer/assessments/${item.id}');
                if (mounted) await _load();
              },
            ),
          ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar anteriores'),
          ),
        if (_message != null)
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Reintentar'),
          ),
      ],
    ),
  );
}

class TrainerStudentAssessmentPage extends StatefulWidget {
  const TrainerStudentAssessmentPage({
    super.key,
    required this.repository,
    required this.deliveryId,
  });
  final ProfessionalAssessmentStudentRepository repository;
  final String deliveryId;
  @override
  State<TrainerStudentAssessmentPage> createState() =>
      _TrainerStudentAssessmentPageState();
}

class _TrainerStudentAssessmentPageState
    extends State<TrainerStudentAssessmentPage> {
  ProfessionalAssessmentDelivery? _delivery;
  Map<String, List<ProfessionalAssessmentAttempt>> _answers = {};
  bool _busy = true, _dirty = false, _confirmed = false;
  String? _message;
  ({
    String operation,
    ProfessionalAssessmentDelivery delivery,
    String action,
    Map<String, List<ProfessionalAssessmentAttempt>> answers,
  })?
  _pending;
  int _captureEpoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final delivery = await widget.repository.delivery(widget.deliveryId);
      if (mounted) {
        setState(() {
          _delivery = delivery;
          _answers = delivery.answers;
          _dirty = false;
          _pending = null;
          _confirmed = false;
          _captureEpoch++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_dirty || _pending != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Consultar la última revisión?'),
          content: const Text(
            'La recarga sustituirá tu borrador local. Una operación ya recibida por el servidor se conserva en su historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar borrador'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Consultar última revisión'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await _load();
  }

  Future<void> _write(String action) async {
    if (_busy || _delivery == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_pending == null) {
        final answers = action == 'start'
            ? <String, List<ProfessionalAssessmentAttempt>>{}
            : ProfessionalAssessmentValidator.answers(
                _delivery!.battery,
                _answers,
                complete: action == 'finish',
              );
        _pending = (
          operation: TrainerInvitationDraft.secure().id,
          delivery: _delivery!,
          action: action,
          answers: answers,
        );
      }
      final pending = _pending!;
      final updated = pending.action == 'start'
          ? await widget.repository.start(pending.operation, pending.delivery)
          : await widget.repository.save(
              pending.operation,
              pending.delivery,
              pending.answers,
              finish: pending.action == 'finish',
            );
      if (mounted) {
        setState(() {
          _delivery = updated;
          _answers = updated.answers;
          _pending = null;
          _dirty = false;
          _confirmed = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _dirty || _pending != null,
      isBusy: () => _busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(delivery?.battery.title ?? 'Prueba asignada'),
          actions: [
            IconButton(
              tooltip: 'Consultar última revisión',
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Text(
                    _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (delivery == null && !_busy)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar carga'),
                  ),
                if (delivery != null) ...[
                  Text(
                    '${delivery.trainerName} · ${delivery.statusLabel} · versión ${delivery.battery.version}',
                  ),
                  Text('Fecha pautada: ${_date(delivery.scheduledDate)}'),
                  const Text(
                    'Marcas de entrenamiento del servicio. No se calculan puntos ni aptitud oficial. No modifica tu preparación ni tu historial personal.',
                  ),
                  if (delivery.status == 'planned' ||
                      delivery.status == 'withdrawn') ...[
                    for (final test in delivery.battery.tests)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                test.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(test.instructions),
                              Text(
                                '${test.maximumAttempts} intentos como máximo · resolución ${test.resolution} ${test.unit.name}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (delivery.canStart)
                      CheckboxListTile(
                        value: _confirmed,
                        onChanged: _busy || _pending != null
                            ? null
                            : (v) => setState(() => _confirmed = v ?? false),
                        title: const Text(
                          'He leído y puedo aplicar íntegramente los protocolos indicados.',
                        ),
                      ),
                    if (delivery.canStart && _pending == null)
                      FilledButton(
                        onPressed: _busy || !_confirmed
                            ? null
                            : () => _write('start'),
                        child: const Text('Comenzar pruebas'),
                      ),
                    if (!delivery.canStart)
                      const Text(
                        'Esta prueba no admite un nuevo inicio. Su contenido se conserva para consulta.',
                      ),
                  ] else ...[
                    AssessmentCaptureFields(
                      key: ValueKey(
                        '${delivery.id}-${delivery.revision}-$_captureEpoch',
                      ),
                      form: delivery.battery,
                      initialAnswers: delivery.answers,
                      readOnly: !delivery.canEdit || _busy || _pending != null,
                      onChanged: (answers) => setState(() {
                        _answers = answers;
                        _dirty = true;
                      }),
                    ),
                    if (delivery.status == 'completed') ...[
                      const Text(
                        'Resultados cerrados. Un intento nulo no equivale a una marca válida de cero.',
                      ),
                      for (final test in delivery.battery.tests)
                        Text(
                          '${test.name}: mejor marca válida '
                          '${ProfessionalAssessmentValidator.best(test, delivery.answers[test.id] ?? const []) ?? 'Sin marca válida'} ${test.unit.name}',
                        ),
                    ],
                    if (delivery.canEdit && _pending == null)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _busy || !_dirty
                                ? null
                                : () => _write('save'),
                            child: const Text('Guardar progreso'),
                          ),
                          FilledButton(
                            onPressed: _busy ? null : () => _write('finish'),
                            child: const Text('Finalizar pruebas'),
                          ),
                        ],
                      ),
                  ],
                  if (_pending != null) ...[
                    const Text(
                      'La operación ya se envió. Reintenta para confirmar la misma revisión y contenido.',
                    ),
                    FilledButton(
                      onPressed: _busy ? null : () => _write(_pending!.action),
                      child: const Text('Reintentar la misma operación'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
