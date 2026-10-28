import 'package:trainer_access/trainer_invitation_link.dart';
import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:trainer_access/trainer_followup_codec.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/professional_assessment.dart';

class MyTrainerPage extends StatefulWidget {
  const MyTrainerPage({
    super.key,
    required this.repository,
    this.forms,
    this.assessments,
    this.onOpenConversation,
    this.calendarSharing,
  });
  final TrainerRepository repository;
  final TrainerStudentFormRepository? forms;
  final ProfessionalAssessmentStudentRepository? assessments;
  final ValueChanged<String>? onOpenConversation;
  final TrainerCalendarSharingRepository? calendarSharing;
  @override
  State<MyTrainerPage> createState() => _MyTrainerPageState();
}

class _MyTrainerPageState extends State<MyTrainerPage> {
  final _secret = TextEditingController();
  List<TrainerRelation> _active = [], _history = [];
  TrainerInvitationPreview? _preview;
  bool _busy = true, _loaded = false, _moreHistory = false;
  String? _error, _notice;
  bool _hasForms = false, _hasAssessments = false;
  String? _assessmentsError;
  String? _formsError;
  TrainerCalendarSharing? _sharing;
  String? _sharingError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final data = await Future.wait([
      widget.repository.relations(asTrainer: false),
      widget.repository.relations(asTrainer: false, ended: true),
    ]);
    if (!mounted) return;
    setState(() {
      _active = data[0];
      _history = data[1];
      _moreHistory = _history.length == 50;
      _loaded = true;
    });
    if (widget.calendarSharing case final repository?) {
      try {
        final sharing = await repository.get();
        if (mounted) {
          setState(() {
            _sharing = sharing;
            _sharingError = null;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _sharing = null;
            _sharingError = trainerError(error);
          });
        }
      }
    }
    if (widget.assessments case final assessments?) {
      try {
        final items = await assessments.mine();
        if (mounted) {
          setState(() {
            _hasAssessments = items.isNotEmpty;
            _assessmentsError = null;
          });
        }
      } catch (error) {
        if (mounted) setState(() => _assessmentsError = trainerError(error));
      }
    }
    final forms = widget.forms;
    if (forms != null) {
      try {
        final deliveries = await forms.mine();
        if (mounted) {
          setState(() {
            _hasForms = deliveries.isNotEmpty;
            _formsError = null;
          });
        }
      } catch (error) {
        // Un fallo de seguimiento no borra ni bloquea la invitación o el vínculo.
        if (mounted) setState(() => _formsError = trainerError(error));
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _loaded = false;
    });
    try {
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(TrainerRelation relation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => EntrenaDialog(
        title: const Text('Finalizar vínculo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dejarás de estar vinculado a ${relation.name}. Para volver necesitarás aceptar otra invitación. Tu historial personal se conserva.',
            ),
            const SizedBox(height: 20),
            EntrenaDialogActions(
              primaryLabel: 'Volver',
              onPrimary: () => Navigator.pop(context, false),
              secondary: [
                OutlinedButton(
                  style: EntrenaButtonStyles.destructive(context),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Finalizar vínculo'),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    await _run(() async {
      await widget.repository.endRelation(relation.id);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_active.length > 1 ? 'Mis preparadores' : 'Mi preparador'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu preparación, acompañada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Acepta solo invitaciones de preparadores que conozcas. Sus pautas conviven en tu agenda y cada conversación se mantiene separada.',
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!),
              ),
            if (_notice != null) Text(_notice!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
            if (_loaded) ...[
              if (_hasAssessments)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Pruebas de mi preparador'),
                    subtitle: const Text(
                      'Protocolos recibidos y marcas registradas',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () async {
                            await context.push('/my-trainer/assessments');
                            if (mounted) await _refresh();
                          },
                  ),
                ),
              if (_assessmentsError != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No se pudieron comprobar tus pruebas. Pulsa Actualizar para reintentar.',
                  ),
                ),
              if (_hasForms)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('Formularios de mi preparador'),
                    subtitle: const Text(
                      'Revisiones recibidas y respuestas anteriores',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () async {
                            await context.push('/my-trainer/forms');
                            if (mounted) await _refresh();
                          },
                  ),
                ),
              if (_formsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No se pudo comprobar si tienes formularios. Pulsa Actualizar para reintentar.',
                  ),
                ),
              if (_sharingError != null)
                Text(
                  'No se pudo comprobar la compartición del calendario. Pulsa Actualizar. $_sharingError',
                ),
              if (_sharing case final sharing?) ...[
                Text(
                  '${_active.length} / ${sharing.maxActiveTrainers} preparadores activos',
                ),
                if (_active.isNotEmpty)
                  Card(
                    child: SwitchListTile(
                      title: const Text(
                        'Compartir mi calendario con mis preparadores',
                      ),
                      subtitle: const Text(
                        'Podrán consultar todas tus sesiones y sus pautas para coordinarse. No comparte conversaciones, resultados ni notas privadas. Puedes desactivarlo cuando quieras.',
                      ),
                      value: sharing.enabled,
                      onChanged: _busy
                          ? null
                          : (enabled) => _run(() async {
                              try {
                                final value = await widget.calendarSharing!.set(
                                  enabled,
                                  sharing.revision,
                                );
                                if (mounted) setState(() => _sharing = value);
                              } catch (_) {
                                await _load();
                                rethrow;
                              }
                            }),
                    ),
                  ),
              ],
              if (_active.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Todavía no tienes preparador. Pídele su código de invitación.',
                    ),
                  ),
                ),
              if (_active.length < (_sharing?.maxActiveTrainers ?? 1)) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _secret,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 512,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación',
                    hintText: 'Pega el código o el enlace que te ha enviado',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _preview = null),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final code = TrainerInvitationLink.fromInput(
                            _secret.text,
                          );
                          if (code == null) {
                            setState(
                              () => _error = 'Pega el código completo o un enlace de invitación de EntrenaOP.',
                            );
                            return;
                          }
                          final preview = await widget.repository.preview(code);
                          if (mounted) setState(() => _preview = preview);
                        }),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Ver invitación'),
                ),
                if (_preview case final preview?)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            preview.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Invitación válida hasta el ${trainerDate(preview.expiresAt)}',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Al aceptar confirmas el vínculo con este preparador. No se contrata ninguna suscripción ni se amplían tus cuotas de creación personal.',
                          ),
                          const SizedBox(height: 12),
                          if (_sharing?.enabled == true)
                            const Text(
                              'Tienes la agenda compartida: este preparador también podrá consultar tu calendario y las pautas de tus sesiones al aceptar.',
                            ),
                          FilledButton(
                            onPressed:
                                _busy ||
                                    _active.any(
                                      (r) => r.personId == preview.trainerId,
                                    )
                                ? null
                                : () => _run(() async {
                                    final code =
                                        TrainerInvitationLink.fromInput(
                                          _secret.text,
                                        );
                                    if (code == null) return;
                                    await widget.repository.accept(code);
                                    if (!mounted) return;
                                    setState(() {
                                      _preview = null;
                                      _secret.clear();
                                      _notice = 'Vínculo aceptado.';
                                    });
                                    await _load();
                                  }),
                            child: const Text('Aceptar y vincularme'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              for (final relation in _active)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('PREPARADOR ACTIVO'),
                        const SizedBox(height: 8),
                        Text(
                          relation.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('Desde el ${trainerDate(relation.acceptedAt)}'),
                        if (widget.onOpenConversation != null)
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => widget.onOpenConversation!(relation.id),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Conversación con mi preparador'),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu acceso personal Free o Pro se mantiene por separado.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _busy ? null : () => _end(relation),
                          child: const Text('Finalizar vínculo'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Vínculos anteriores',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final relation in _history)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(relation.name),
                    subtitle: Text(
                      'Finalizado el ${trainerDate(relation.endedAt!)}',
                    ),
                    onTap: widget.onOpenConversation == null
                        ? null
                        : () => widget.onOpenConversation!(relation.id),
                  ),
                if (_moreHistory)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final more = await widget.repository.relations(
                              asTrainer: false,
                              ended: true,
                              before: _history.last,
                            );
                            if (mounted) {
                              setState(() {
                                _history.addAll(more);
                                _moreHistory = more.length == 50;
                              });
                            }
                          }),
                    child: const Text('Ver más vínculos'),
                  ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
