import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_client_workspace_repository.dart';
import 'trainer_form_pages.dart';
import 'trainer_form_repository.dart';
import 'trainer_assessment_pages.dart';
import 'trainer_assessment_repository.dart';

/// La ruta se resuelve por identidad persistida, incluso al recargar el navegador.
class TrainerClientContentRoute extends StatefulWidget {
  const TrainerClientContentRoute({
    super.key,
    required this.workspace,
    this.forms,
    this.assessments,

    required this.clientId,
  }) : assert((forms == null) != (assessments == null));
  final TrainerClientWorkspaceRepository workspace;
  final TrainerFormRepository? forms;
  final TrainerAssessmentRepository? assessments;
  final String clientId;
  @override
  State<TrainerClientContentRoute> createState() =>
      _TrainerClientContentRouteState();
}

class _TrainerClientContentRouteState extends State<TrainerClientContentRoute> {
  late Future<TrainerClientWorkspace> _future = widget.workspace.get(
    widget.clientId,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<TrainerClientWorkspace>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.assessments == null
                  ? 'Formularios del alumno'
                  : 'Pruebas del alumno',
            ),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trainerError(snapshot.error!)),
                TextButton(
                  onPressed: () => setState(() {
                    _future = widget.workspace.get(widget.clientId);
                  }),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      if (widget.assessments case final assessments?) {
        return TrainerClientAssessmentsPage(
          repository: assessments,
          client: snapshot.data!.client,
        );
      }
      return TrainerClientFormsPage(
        repository: widget.forms!,
        client: snapshot.data!.client,
      );
    },
  );
}
