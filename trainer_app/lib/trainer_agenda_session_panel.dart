import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_template_content.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';

/// Una ruta superpuesta mantiene montada la agenda: semana, filtros y scroll.
Future<T?> showTrainerAgendaPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black26,
  transitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) {
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 900;
    return Align(
      alignment: desktop ? Alignment.centerRight : Alignment.bottomCenter,
      child: SizedBox(
        width: desktop ? 560 : size.width,
        height: desktop ? size.height : size.height * .94,
        child: Material(
          elevation: 12,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(child: builder(context)),
        ),
      ),
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position:
            Tween<Offset>(
              begin: MediaQuery.sizeOf(context).width >= 900
                  ? const Offset(1, 0)
                  : const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
);

class TrainerAgendaSessionPanel extends StatefulWidget {
  const TrainerAgendaSessionPanel({
    super.key,
    required this.name,
    required this.personName,
    required this.metadata,
    required this.actions,
    this.note,
    this.readOnly = false,
    this.loadRecipe,
    this.repository,
    this.assignmentId,
    this.hasResult = false,
  });
  final String name, personName, metadata;
  final String? note, assignmentId;
  final bool readOnly, hasResult;
  final Future<WorkoutTemplate?> Function()? loadRecipe;
  final TrainerWorkoutRepository? repository;
  final List<Widget> Function(BuildContext) actions;

  @override
  State<TrainerAgendaSessionPanel> createState() =>
      _TrainerAgendaSessionPanelState();
}

class _TrainerAgendaSessionPanelState extends State<TrainerAgendaSessionPanel> {
  late Future<WorkoutTemplate?>? _recipe = widget.loadRecipe?.call();
  Future<WorkoutJson?>? _result;
  bool _showResult = false;

  Widget _failure(Object error, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trainerError(error)),
          TextButton(onPressed: retry, child: const Text('Reintentar detalle')),
        ],
      ),
    ),
  );

  Widget _content() {
    if (_showResult) {
      return FutureBuilder<WorkoutJson?>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _failure(
              snapshot.error!,
              () => setState(() {
                _result = widget.repository!.result(widget.assignmentId!);
              }),
            );
          }
          final row = snapshot.data;
          if (row == null) {
            return const Center(
              child: Text('Todavía no hay una ejecución de esta pauta.'),
            );
          }
          return TrainerWorkoutResultContent(
            result: row,
            loadHistory: (cursor) =>
                loadTrainerComparisonPage(widget.repository!, row, cursor),
          );
        },
      );
    }
    if (_recipe == null) {
      return const Center(
        child: Text('Abre la planificación para consultar la receta.'),
      );
    }
    return FutureBuilder<WorkoutTemplate?>(
      future: _recipe,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _failure(
            snapshot.error!,
            () => setState(() {
              _recipe = widget.loadRecipe!();
            }),
          );
        }
        if (snapshot.data == null) {
          return const Center(
            child: Text('La receta no está disponible. Actualiza la agenda.'),
          );
        }
        return SingleChildScrollView(
          key: const PageStorageKey('agenda-recipe-scroll'),
          padding: const EdgeInsets.all(20),
          child: WorkoutTemplateContent(
            template: snapshot.data!,
            showTitle: false,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('agenda-session-panel'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.personName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      Flexible(
        flex: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .25,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(widget.metadata),
                if (widget.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(widget.note!),
                ],
                if (widget.readOnly)
                  const Text('Pauta de tu preparador · Solo lectura'),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Receta'),
              selected: !_showResult,
              onSelected: (_) => setState(() => _showResult = false),
            ),
            if (widget.hasResult && widget.repository != null)
              ChoiceChip(
                label: const Text('Resultados'),
                selected: _showResult,
                onSelected: (_) => setState(() {
                  _result ??= widget.repository!.result(widget.assignmentId!);
                  _showResult = true;
                }),
              ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(child: _content()),
      const Divider(height: 1),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .28,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.actions(context),
          ),
        ),
      ),
    ],
  );
}
