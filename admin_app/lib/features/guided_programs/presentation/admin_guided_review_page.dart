import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_core/workout_template.dart';

import '../../editorial_covers/domain/program_cover.dart';
import '../../publication/presentation/publication_review_panel.dart';
import '../../workouts/data/admin_workout_repository.dart';
import '../../workouts/presentation/admin_workout_content.dart';
import '../domain/admin_guided_repository.dart';

class AdminGuidedReviewPage extends StatefulWidget {
  const AdminGuidedReviewPage({
    super.key,
    required this.programId,
    required this.repository,
    required this.workouts,
    this.covers,
  });
  final String programId;
  final AdminGuidedRepository repository;
  final AdminWorkoutRepository workouts;
  final ProgramCoverRepository? covers;

  @override
  State<AdminGuidedReviewPage> createState() => _AdminGuidedReviewPageState();
}

class _AdminGuidedReviewPageState extends State<AdminGuidedReviewPage> {
  late Future<_Review> _review;
  final _templates = <String, Future<WorkoutTemplate?>>{};
  final _contentErrors = <String, String>{};
  final _loading = <String>{};
  final _expanded = <String>{};
  int _generation = 0;
  bool _busy = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _review = _fetch();
  }

  Future<_Review> _fetch() async {
    final result = await (
      widget.repository.program(widget.programId),
      widget.workouts.listGeneral(),
      widget.repository.warmups(),
      widget.covers?.load(widget.programId) ?? Future<ProgramCover?>.value(),
    ).wait;
    return _Review(result.$1, result.$2, result.$3, result.$4);
  }

  void _clearContent() {
    _generation++;
    _templates.clear();
    _contentErrors.clear();
    _loading.clear();
    _expanded.clear();
  }

  void _reload() => setState(() {
    _clearContent();
    _error = null;
    _review = _fetch();
  });

  Future<void> _publish(_Review reviewed) async {
    if (_busy ||
        _confirming ||
        reviewed.errors.isNotEmpty ||
        _contentErrors.isNotEmpty ||
        _loading.isNotEmpty) {
      return;
    }
    _confirming = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => EntrenaDialog(
          title: const Text('Publicar programa'),
          content: Text(
            '«${reviewed.program.name}», versión ${reviewed.program.version}, aparecerá en Biblioteca con ${reviewed.program.sessionCount} sesiones. El deportista tendrá que iniciarlo expresamente. No crea seguimientos ni modifica agendas existentes.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Publicar en Biblioteca',
              onPrimary: () => Navigator.of(dialogContext).pop(true),
              secondary: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Seguir revisando'),
                ),
              ],
            ),
          ],
        ),
      );
    } finally {
      _confirming = false;
    }
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Se releen las referencias tras confirmar; una revisión antigua nunca
      // publica deliberadamente contenido cambiado en otra pestaña.
      final latest = await _fetch();
      if (!mounted) return;
      if (latest.signature != reviewed.signature ||
          latest.program.status != 'draft' ||
          latest.errors.isNotEmpty) {
        setState(() {
          _clearContent();
          _review = Future.value(latest);
          _error = 'El contenido o su disponibilidad han cambiado. Revisa la información actualizada antes de publicar.';
        });
        return;
      }
      await widget.repository.setStatus(widget.programId, 'published');
      if (mounted) {
        setState(() => _busy = false);
        context.canPop() ? context.pop(true) : context.go('/guided-programs');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo publicar. El borrador sigue guardado. Actualiza la revisión y comprueba la conexión antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<WorkoutTemplate?> _template(
    String id,
    String name,
  ) => _templates.putIfAbsent(id, () async {
    final generation = _generation;
    _loading.add(id);
    try {
      final result = await widget.workouts.getTemplateById(id);
      if (result == null ||
          result.id != id ||
          result.blocks.isEmpty ||
          result.blocks.any(
            (b) => b.items.isEmpty || b.items.any((i) => i.sets.isEmpty),
          )) {
        throw const FormatException('Contenido incompleto');
      }
      return result;
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _contentErrors[id] =
              'No se ha podido revisar el contenido de «$name». Reintenta su carga.',
        );
      }
      rethrow;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading.remove(id));
      }
    }
  });

  Widget _reader(String id, String name) => FutureBuilder<WorkoutTemplate?>(
    future: _template(id, name),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No se pudo cargar el contenido.'),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _templates.remove(id);
                      _contentErrors.remove(id);
                    }),
              child: const Text('Reintentar contenido'),
            ),
          ],
        );
      }
      return AdminWorkoutContent(template: snapshot.data!, showTitle: false);
    },
  );

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => false,
    isBusy: () => _busy || _confirming,
    child: Scaffold(
      appBar: AppBar(title: const Text('Revisar programa')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: FutureBuilder<_Review>(
            future: _review,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar la revisión del programa.'),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              return _content(snapshot.data!);
            },
          ),
        ),
      ),
    ),
  );

  Widget _content(_Review review) {
    final p = review.program;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Vista previa', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Despliega las sesiones para revisar ejercicios, series y descansos.',
        ),
        const SizedBox(height: 16),
        EntrenaProgramCard(
          title: p.name,
          label: p.modeLabel,
          detail: '${p.sessionCount} sesiones',
          actionLabel: 'Ver programa →',
          categoryLabel: p.primaryCategory?.name,
          icon: p.mode == GuidedProgramMode.guide
              ? Icons.repeat
              : Icons.route_outlined,
          coverImage: review.cover?.cardUrl == null
              ? null
              : NetworkImage(review.cover!.cardUrl!),
          focalX: review.cover?.focalX ?? .5,
          focalY: review.cover?.focalY ?? .5,
        ),
        const SizedBox(height: 16),
        Text(
          'Versión ${p.version} · ${p.status == 'draft'
              ? 'Borrador privado'
              : p.status == 'published'
              ? 'Publicado'
              : 'Retirado'}',
        ),
        if (p.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(p.description),
          ),
        if (p.audience.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Dirigido a: ${p.audience}'),
          ),
        if (p.equipment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Material: ${p.equipment}'),
          ),
        if (p.categories.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in p.categories) Chip(label: Text(c.name))],
          ),
        const SizedBox(height: 24),
        for (var n = 0; n < p.phases.length; n++) ...[
          Text(
            '${n + 1}. ${p.phases[n].name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            p.mode == GuidedProgramMode.guide
                ? 'Secuencia repetible, sin plazo de finalización.'
                : '${p.phases[n].durationWeeks ?? '—'} semanas orientativas. El avance se confirma, no ocurre por calendario.',
          ),
          if (p.phases[n].instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Condiciones de avance: ${p.phases[n].instructions}'),
            ),
          for (var i = 0; i < p.phases[n].sessions.length; i++)
            _session(review, p.phases[n].sessions[i], n, i),
          const SizedBox(height: 24),
        ],
        PublicationReviewPanel(
          errors: [...review.errors, ..._contentErrors.values],
          suggestions: review.suggestions,
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await context.push(
                        '/guided-programs/${Uri.encodeComponent(widget.programId)}/edit',
                      );
                      if (mounted) _reload();
                    },
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                p.status == 'draft' ? 'Editar borrador' : 'Crear revisión',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar revisión'),
            ),
            if (p.status == 'draft')
              FilledButton.icon(
                onPressed:
                    _busy ||
                        review.errors.isNotEmpty ||
                        _contentErrors.isNotEmpty ||
                        _loading.isNotEmpty
                    ? null
                    : () => _publish(review),
                icon: const Icon(Icons.publish_outlined),
                label: Text(_busy ? 'Publicando…' : 'Publicar programa'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Publicar añade esta versión a Biblioteca. Cada deportista debe iniciar el programa; no cambia los seguimientos ni las agendas existentes.',
        ),
      ],
    );
  }

  Widget _session(_Review review, GuidedSession session, int phase, int index) {
    final source = review.sessionById[session.templateId];
    final warmup = review.warmupById[session.warmupId];
    final expansion = '$phase-$index';
    return Card(
      child: ExpansionTile(
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        enabled: !_busy,
        onExpansionChanged: (open) => setState(() {
          open ? _expanded.add(expansion) : _expanded.remove(expansion);
        }),
        key: ValueKey('${widget.programId}-$phase-$index-${review.signature}'),
        title: Text('${index + 1}. ${session.name}'),
        subtitle: Text(
          source == null
              ? 'Sesión no disponible'
              : '${source.name} · v${source.version} · ${source.status == 'published' ? 'Publicada' : 'No publicada'}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: _expanded.contains(expansion)
            ? [
                if (session.restPolicy.adjustable)
                  Text(
                    'Descanso ajustable entre series: ${session.restPolicy.minimumSeconds}–${session.restPolicy.maximumSeconds} s. Se aplica a los bloques convencionales; los demás formatos conservan su pauta.',
                  ),
                if (warmup != null) ...[
                  Text(
                    'Calentamiento opcional: ${warmup.name} · v${warmup.version}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('El deportista puede omitir este calentamiento.'),
                  _reader(warmup.templateId, warmup.name),
                  const Divider(),
                ],
                _reader(session.templateId, session.name),
              ]
            : const [],
      ),
    );
  }
}

class _Review {
  _Review(this.program, this.sessions, this.warmups, this.cover);
  final GuidedProgram program;
  final List<AdminWorkoutSummary> sessions;
  final List<GuidedWarmup> warmups;
  final ProgramCover? cover;

  late final sessionById = {for (final s in sessions) s.id: s};
  late final warmupById = {for (final w in warmups) w.id: w};

  late final String signature = jsonEncode([
    guidedProgramToJson(program),
    program.version,
    program.primaryCategoryId,
    for (final c in program.categories) [c.id, c.name, c.active],
    cover?.revision,
  ]);

  late final List<String> errors = _issues();

  List<String> _issues() {
    final problems = <String>{};
    try {
      validateGuidedProgram(program);
    } on FormatException catch (e) {
      problems.add(e.message);
    }
    for (final phase in program.phases) {
      for (final session in phase.sessions) {
        final source = sessionById[session.templateId];
        if (source == null || source.status != 'published') {
          problems.add(
            '«${session.name}» no está disponible como sesión publicada.',
          );
        }
        if (session.warmupId != null &&
            !warmups.any(
              (w) => w.id == session.warmupId && w.status == 'published',
            )) {
          problems.add(
            'El calentamiento de «${session.name}» no está publicado o no está disponible.',
          );
        }
        if (session.warmupId != null && source?.hasWarmup == true) {
          problems.add(
            '«${session.name}» ya incluye calentamiento. Quita el calentamiento adjunto.',
          );
        }
        if (session.restPolicy.adjustable &&
            source?.supportsAdjustableRest != true) {
          problems.add(
            'El formato de «${session.name}» no admite el ajuste genérico de descanso.',
          );
        }
      }
    }
    return problems.toList();
  }

  List<String> get suggestions => [
    if (program.description.trim().isEmpty)
      'Añade una descripción que explique el objetivo y cómo usar el programa.',
    if (program.audience.trim().isEmpty)
      'Puedes indicar a quién va dirigido y qué nivel previo requiere.',
    if (program.categories.isEmpty)
      'Las categorías ayudan a encontrar el programa en Biblioteca.',
    if (cover != null && !cover!.hasImage)
      'Puedes añadir una portada desde el catálogo.',
  ];
}
