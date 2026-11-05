import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/admin_builtin_program_repository.dart';
import '../data/admin_builtin_assessment_authoring_repository.dart';
import 'admin_builtin_assessment_authoring_panel.dart';

class AdminBuiltinProgramPanel extends StatefulWidget {
  const AdminBuiltinProgramPanel({
    super.key,
    required this.programId,
    required this.repository,
    this.authoringRepository,
  });
  final String programId;
  final AdminBuiltinProgramRepository repository;
  final AdminBuiltinAssessmentAuthoringRepository? authoringRepository;
  @override
  State<AdminBuiltinProgramPanel> createState() =>
      _AdminBuiltinProgramPanelState();
}

class _AdminBuiltinProgramPanelState extends State<AdminBuiltinProgramPanel> {
  late Future<AdminBuiltinProgramData> _data = widget.repository.load(
    widget.programId,
  );
  @override
  void didUpdateWidget(covariant AdminBuiltinProgramPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.programId != widget.programId ||
        oldWidget.repository != widget.repository) {
      _data = widget.repository.load(widget.programId);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.authoringRepository != null) ...[
        AdminBuiltinAssessmentAuthoringPanel(
          key: ValueKey('builtin-authoring-${widget.programId}'),
          programId: widget.programId,
          repository: widget.authoringRepository!,
          onPublished: () => setState(() {
            _data = widget.repository.load(widget.programId);
            _data.ignore();
          }),
        ),
        const SizedBox(height: 24),
      ],
      _legacy(context),
    ],
  );

  Widget _legacy(
    BuildContext context,
  ) => FutureBuilder<AdminBuiltinProgramData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authoringRepository == null
                      ? 'No se pudo consultar el catálogo oficial. Esto no significa que la preparación esté vacía.'
                      : 'No se pudieron consultar las condiciones de entrenamiento. Las versiones de evaluación se consultan por separado.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _data = widget.repository.load(widget.programId);
                    _data.ignore();
                  }),
                  child: const Text('Reintentar catálogo oficial'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!;
      final ids = data.standards.map((s) => s.testId).toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.authoringRepository == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catálogo oficial · consulta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(data.name),
                    SelectableText('Versión: ${data.version}'),
                    SelectableText('Fuente: ${data.sourceUrl}'),
                    Text('Vigencia desde ${data.effectiveFrom}'),
                    const SizedBox(height: 8),
                    Text(
                      data.isFas
                          ? 'Mínimos de referencia de 20 puntos por prueba, sexo y edad. Esta consulta no es la tabla completa de puntuación de 0 a 100.'
                          : 'Mínimos por prueba, sexo e hito de ingreso o formación.',
                    ),
                    if (data.isFas)
                      const Text(
                        'Consulta también las condiciones de edad por objetivo; la etiqueta del baremo no sustituye esas condiciones.',
                      ),
                    const Text(
                      'Esta preparación usa un catálogo y adaptadores propios. Consultar sus datos no modifica resultados ni los convierte en un borrador configurable.',
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Pruebas y mínimos · ${ids.length} pruebas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final id in ids)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('builtin-${data.programId}-$id'),
                  title: Text(
                    data.standards.firstWhere((s) => s.testId == id).name,
                  ),
                  subtitle: Text(
                    '${data.standards.where((s) => s.testId == id).length} mínimos · solo consulta',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    for (final row in data.standards.where(
                      (s) => s.testId == id,
                    ))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${_category(row.category)} · ${_group(row.group)}: ${row.direction == 'higher' ? 'al menos' : 'hasta'} ${row.formattedThreshold}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Objetivos y condiciones de entrenamiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Las sesiones adaptativas se generan según el contexto y los registros de cada deportista. No son una colección fija de sesiones del catálogo editorial.',
          ),
          if (data.objectives.isEmpty)
            const Text(
              'La consulta no devuelve objetivos específicos de rendimiento para este programa.',
            ),
          for (final row in data.objectives)
            Card(
              child: ExpansionTile(
                // El plegado no comparte estado con el scroll de la ficha ni
                // con el desplazamiento interno de los textos seleccionables.
                key: PageStorageKey(
                  'builtin-objective-${data.programId}-${row['objective_key']}',
                ),
                title: Text(row['name'] as String),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(row['instructions'] as String),
                  ),
                  if (row['max_age_exclusive'] != null)
                    Text(
                      'Aplicable antes de ${row['max_age_exclusive']} años.',
                    ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Perfil ${row['profile_code']} · v${row['profile_version']}',
                    key: const PageStorageKey('objective-profile'),
                  ),
                  SelectableText(
                    'Protocolo ${row['protocol_key']} · v${row['protocol_version']}',
                    key: const PageStorageKey('objective-protocol'),
                  ),
                  if ((row['parameters'] as Map).isNotEmpty)
                    SelectableText(
                      'Condiciones: ${jsonEncode(row['parameters'])}',
                      key: const PageStorageKey('objective-parameters'),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

String _category(String value) => switch (value) {
  'men' => 'Hombres',
  'women' => 'Mujeres',
  _ => value,
};
String _group(String value) => switch (value) {
  'entry' => 'Ingreso',
  'end_of_general_military_training' => 'Fin de formación militar general',
  'end_of_training' => 'Fin de formación',
  '60_plus' => '60 años o más',
  _ => '${value.replaceAll('_', '–')} años',
};
