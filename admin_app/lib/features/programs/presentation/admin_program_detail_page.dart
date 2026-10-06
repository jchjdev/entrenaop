import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_attempt_preview_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_scoring_editor.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_test_pass_standards_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:flutter/material.dart';

import 'admin_performance_strategy_section.dart';

import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';

import 'program_cover_editor.dart';

class AdminProgramDetailPage extends StatefulWidget {
  const AdminProgramDetailPage({
    super.key,
    required this.program,
    required this.repository,
    required this.workoutRepository,
    this.coverRepository,
  });

  final AdminProgram program;
  final AdminProgramRepository repository;
  final AdminWorkoutRepository workoutRepository;
  final ProgramCoverRepository? coverRepository;

  @override
  State<AdminProgramDetailPage> createState() => _AdminProgramDetailPageState();
}

class _AdminProgramDetailPageState extends State<AdminProgramDetailPage> {
  late Future<List<AdminProgramTest>> _tests = widget.repository.listTests(
    widget.program.id,
  );
  late Future<AdminProgramScoringRule?> _rule = widget.repository
      .getScoringRule(widget.program.id);
  late Future<List<AdminProgramTrainingModule>> _modules = widget.repository
      .listTrainingModules(widget.program.id);
  String? _selectedRunningTestId;
  bool _saving = false;

  Future<void> _setRunningModule(String testId, {required bool enabled}) async {
    setState(() => _saving = true);
    try {
      await widget.repository.setRunningTwoKilometreModule(
        testId,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _modules = widget.repository.listTrainingModules(widget.program.id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el módulo de carrera.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cloneVersion() async {
    final rule = await _rule;
    if (!mounted || rule == null) return;
    final name = TextEditingController(
      text: '${widget.program.name} · nueva edición',
    );
    final version = TextEditingController(text: '${rule.version}_v2');
    final form = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear nueva versión'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Se copiarán las pruebas y baremos a un borrador nuevo. Las evaluaciones anteriores conservarán esta versión.',
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del programa nuevo',
                  ),
                  maxLength: 120,
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Indica un nombre.'
                      : null,
                ),
                TextFormField(
                  controller: version,
                  decoration: const InputDecoration(
                    labelText: 'Versión nueva del baremo',
                  ),
                  maxLength: 120,
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 3 ||
                          value?.trim() == rule.version
                      ? 'Indica una versión diferente.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (name.text.trim(), version.text.trim()));
              }
            },
            child: const Text('Crear borrador'),
          ),
        ],
      ),
    );
    name.dispose();
    version.dispose();
    if (values == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.cloneAssessmentVersion(
        widget.program.id,
        values.$1,
        values.$2,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear la versión. Revisa sus datos.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _saving = true);
    try {
      final issues = await widget.repository.assessmentIssues(
        widget.program.id,
      );
      if (!mounted) return;
      if (issues.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Falta completar el baremo'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final issue in issues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $issue'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Seguir editando'),
              ),
            ],
          ),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publicar evaluación'),
          content: const Text(
            'El programa aparecerá a los deportistas. Sus pruebas y baremos quedarán bloqueados para conservar los resultados históricos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.repository.publishAssessment(widget.program.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo publicar. Revisa de nuevo el baremo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editRule(AdminProgramScoringRule? current) async {
    final rule = await showScoringRuleDialog(context, current);
    if (rule == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveScoringRule(widget.program.id, rule);
      if (!mounted) return;
      setState(
        () => _rule = widget.repository.getScoringRule(widget.program.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Regla de calificación guardada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la regla de calificación.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createTest() async {
    final existing = await _tests;
    if (!mounted) return;
    final test = await showDialog<AdminProgramTest>(
      context: context,
      builder: (_) => _NewProgramTestDialog(existingTests: existing),
    );
    if (test == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createTest(widget.program.id, test);
      if (!mounted) return;
      setState(() {
        _tests = widget.repository.listTests(widget.program.id);
        _modules = widget.repository.listTrainingModules(widget.program.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prueba añadida al borrador.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la prueba. Revisa si ya existe.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editTest(AdminProgramTest current) async {
    final existing = await _tests;
    if (!mounted) return;
    final edited = await showDialog<AdminProgramTest>(
      context: context,
      builder: (_) =>
          _NewProgramTestDialog(existing: current, existingTests: existing),
    );
    if (edited == null || !mounted) return;
    final bands = await widget.repository.listScoreBands(current.id);
    final standards = await widget.repository.listPassStandards(current.id);
    if (!mounted) return;
    final changesMeasurement =
        current.unit != edited.unit ||
        current.betterDirection != edited.betterDirection ||
        current.distanceMeters != edited.distanceMeters ||
        current.measurementProtocol != edited.measurementProtocol ||
        current.category != edited.category ||
        current.markStep != edited.markStep ||
        bands.any(
          (band) => band.minAge < edited.minAge || band.maxAge > edited.maxAge,
        ) ||
        standards.any(
          (standard) =>
              standard.minAge < edited.minAge ||
              standard.maxAge > edited.maxAge,
        );
    if (current.unit != edited.unit ||
        current.betterDirection != edited.betterDirection ||
        current.distanceMeters != edited.distanceMeters ||
        current.measurementProtocol != edited.measurementProtocol) {
      final modules = await _modules;
      if (!mounted) return;
      if (modules.any((module) => module.testId == current.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Desvincula el módulo antes de cambiar la medición.'),
          ),
        );
        return;
      }
    }
    if (changesMeasurement && (bands.isNotEmpty || standards.isNotEmpty)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar cómo se mide la prueba'),
          content: Text(
            'Se borrarán ${bands.length} tramos y ${standards.length} mínimos de ${current.name}. Tendrás que crear de nuevo su baremo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cambiar y borrar baremo'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.updateTest(
        edited,
        resetBands: changesMeasurement,
      );
      if (!mounted) return;
      setState(() {
        _tests = widget.repository.listTests(widget.program.id);
        _modules = widget.repository.listTrainingModules(widget.program.id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Prueba actualizada.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la prueba. Revisa sus datos.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTest(AdminProgramTest test) async {
    final bands = await widget.repository.listScoreBands(test.id);
    final standards = await widget.repository.listPassStandards(test.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar prueba'),
        content: Text(
          '¿Borrar ${test.name}, sus ${bands.length} tramos y ${standards.length} mínimos del borrador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar prueba'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteTest(test.id);
      if (!mounted) return;
      setState(() {
        _tests = widget.repository.listTests(widget.program.id);
        _modules = widget.repository.listTrainingModules(widget.program.id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar la prueba.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.program.name)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.program.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.program.enabled
                  ? 'Programa publicado · las pruebas existentes se conservan.'
                  : 'Borrador · define sus pruebas antes de publicarlo.',
            ),
            if (!widget.program.enabled) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _publish,
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Revisar y publicar'),
                ),
              ),
            ],
            if (widget.program.enabled) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _cloneVersion,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Crear nueva versión editable'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (widget.coverRepository != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Imagen de preparación'),
                  subtitle: const Text('Portada, encuadre y vista previa'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.all(20),
                      child: ProgramCoverEditor(
                        programId: widget.program.id,
                        programName: widget.program.name,
                        repository: widget.coverRepository!,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('Sesiones del programa'),
                subtitle: const Text('Plantillas de entrenamiento'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminProgramWorkoutsPage(
                      program: widget.program,
                      repository: widget.workoutRepository,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Calificación',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<AdminProgramScoringRule?>(
              future: _rule,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'No se pudo cargar la regla de calificación.',
                  );
                }
                if (!snapshot.hasData &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                final rule = snapshot.data;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule == null
                              ? 'Sin regla de evaluación. Define fuente y criterio de aprobado.'
                              : '${rule.sourceLabel} · ${rule.version}',
                        ),
                        if (rule != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            rule.scoringMode == 'pass_fail'
                                ? 'Apto / no apto por mínimos · ${rule.stageLabel}'
                                : '${rule.aggregation == 'average'
                                      ? 'Media'
                                      : rule.aggregation == 'sum'
                                      ? 'Suma'
                                      : 'Mínimos por prueba'} · mínimo por prueba ${formatMark(rule.minEachPoints)} · mínimo total ${formatMark(rule.minAggregatePoints)}',
                          ),
                        ],
                        if (!widget.program.enabled) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : () => _editRule(rule),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              rule == null
                                  ? 'Definir calificación'
                                  : 'Editar calificación',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pruebas del programa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!widget.program.enabled)
                  FilledButton.icon(
                    onPressed: _saving ? null : _createTest,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir prueba'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Define cada ejercicio para H, M o ambos y sus edades. Después añade mínimos o tramos de puntuación. Un borrador incompleto no se usa para evaluar.',
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AdminProgramTest>>(
              future: _tests,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(() {
                      _tests = widget.repository.listTests(widget.program.id);
                    }),
                    child: const Text(
                      'No se pudieron cargar las pruebas. Reintentar',
                    ),
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Este programa todavía no tiene pruebas definidas.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminProgramAttemptPreviewPage(
                              program: widget.program,
                              tests: snapshot.data!,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Simular calificación'),
                      ),
                    ),
                    for (final test in snapshot.data!)
                      Card(
                        child: ExpansionTile(
                          title: Text(test.name),
                          subtitle: Text(
                            'Ejercicio ${test.displayOrder} · ${categoryLabel(test.category)} · ${test.minAge}–${test.maxAge} años · ${_unitLabel(test.unit)}${test.distanceMeters == null ? '' : ' · ${test.distanceMeters} m'}${test.measurementProtocol == 'run_2000m_v1' ? ' · carrera 2 km' : ''} · ${test.maxAttempts == 1 ? 'un intento' : '${test.maxAttempts} intentos ${test.retryPolicy == 'invalid_only' ? 'solo tras nulo' : 'máximo'}'}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(test.protocolNotes),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.table_chart_outlined),
                              title: const Text('Editar baremo de la prueba'),
                              subtitle: const Text(
                                'Mínimos o puntos por columna H/M y edad',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final rule = await _rule;
                                if (!context.mounted) return;
                                if (rule == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Define primero la calificación del programa.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        rule.scoringMode == 'pass_fail'
                                        ? AdminTestPassStandardsPage(
                                            test: test,
                                            repository: widget.repository,
                                            editable: !widget.program.enabled,
                                          )
                                        : AdminTestScoreBandsPage(
                                            programId: widget.program.id,
                                            test: test,
                                            repository: widget.repository,
                                            editable: !widget.program.enabled,
                                          ),
                                  ),
                                );
                              },
                            ),
                            if (!widget.program.enabled)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _editTest(test),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Editar prueba'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () => _deleteTest(test),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Borrar prueba'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Módulos de entrenamiento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vincula cada prueba con su preparación deportiva. El deportista aportará su contexto y revisará la propuesta antes de guardarla en agenda.',
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<AdminProgramTest>>(
              future: _tests,
              builder: (context, testsSnapshot) =>
                  FutureBuilder<List<AdminProgramTrainingModule>>(
                    future: _modules,
                    builder: (context, modulesSnapshot) {
                      if (testsSnapshot.hasError || modulesSnapshot.hasError) {
                        return const Text('No se pudieron cargar los módulos.');
                      }
                      if (!testsSnapshot.hasData || !modulesSnapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final tests = testsSnapshot.data!;
                      final modules = modulesSnapshot.data!;
                      final eligible = tests
                          .where(
                            (test) =>
                                test.unit == 'seconds' &&
                                test.betterDirection == 'lower' &&
                                test.distanceMeters == 2000 &&
                                test.measurementProtocol == 'run_2000m_v1' &&
                                !modules.any(
                                  (module) => module.testId == test.id,
                                ),
                          )
                          .toList();
                      final selected =
                          eligible.any(
                            (test) => test.id == _selectedRunningTestId,
                          )
                          ? _selectedRunningTestId
                          : null;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final module in modules)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.directions_run),
                                  title: const Text(
                                    'Preparación de carrera 2 km',
                                  ),
                                  subtitle: Text(
                                    tests
                                            .where(
                                              (test) =>
                                                  test.id == module.testId,
                                            )
                                            .map((test) => test.name)
                                            .firstOrNull ??
                                        'Prueba vinculada',
                                  ),
                                  trailing: widget.program.enabled
                                      ? null
                                      : TextButton(
                                          onPressed: _saving
                                              ? null
                                              : () => _setRunningModule(
                                                  module.testId,
                                                  enabled: false,
                                                ),
                                          child: const Text('Desvincular'),
                                        ),
                                ),
                              if (modules.isEmpty)
                                const Text('Sin módulos vinculados.'),
                              if (!widget.program.enabled) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(selected),
                                  initialValue: selected,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Prueba cronometrada de 2.000 m',
                                  ),
                                  items: [
                                    for (final test in eligible)
                                      DropdownMenuItem(
                                        value: test.id,
                                        child: Text(test.name),
                                      ),
                                  ],
                                  onChanged: eligible.isEmpty
                                      ? null
                                      : (value) => setState(
                                          () => _selectedRunningTestId = value,
                                        ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: _saving || selected == null
                                      ? null
                                      : () => _setRunningModule(
                                          selected,
                                          enabled: true,
                                        ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Vincular carrera 2 km'),
                                ),
                                if (eligible.isEmpty)
                                  const Text(
                                    'Define antes una prueba en segundos, con mejor marca baja, 2.000 m y protocolo de carrera continua.',
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<AdminProgramTest>>(
              future: _tests,
              builder: (context, snapshot) => snapshot.hasData
                  ? AdminPerformanceStrategySection(
                      program: widget.program,
                      tests: snapshot.data!,
                      repository: widget.repository,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
}

String _unitLabel(String unit) => switch (unit) {
  'repetitions' => 'Repeticiones',
  'seconds' => 'Segundos',
  'meters' => 'Metros',
  _ => unit,
};

class _NewProgramTestDialog extends StatefulWidget {
  const _NewProgramTestDialog({this.existing, this.existingTests = const []});

  final AdminProgramTest? existing;
  final List<AdminProgramTest> existingTests;

  @override
  State<_NewProgramTestDialog> createState() => _NewProgramTestDialogState();
}

class _NewProgramTestDialogState extends State<_NewProgramTestDialog> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _protocol = TextEditingController();
  final _order = TextEditingController(text: '1');
  final _step = TextEditingController(text: '1');
  final _minAge = TextEditingController();
  final _maxAge = TextEditingController();
  final _maxAttempts = TextEditingController(text: '2');
  final _distance = TextEditingController();
  String _unit = 'repetitions';
  String _direction = 'higher';
  String _category = 'both';
  String _retryPolicy = 'none';
  bool _continuous2000mProtocol = false;

  AdminProgramTest? _variantAt(int order) => widget.existingTests
      .where(
        (test) =>
            test.displayOrder == order &&
            test.category != 'both' &&
            _category != 'both' &&
            test.category != _category,
      )
      .firstOrNull;

  String? _validateOrder(String? raw) {
    final order = int.tryParse(raw ?? '');
    if (order == null || order <= 0) return 'Introduce un número positivo.';
    final current = widget.existing;
    if (current != null) {
      if (widget.existingTests.any(
        (test) =>
            test.id != current.id &&
            test.displayOrder == order &&
            test.groupCode != current.groupCode,
      )) {
        return 'Este número ya corresponde a otra prueba.';
      }
      if (widget.existingTests.any(
            (test) =>
                test.id != current.id && test.groupCode == current.groupCode,
          ) &&
          order != current.displayOrder) {
        return 'Las variantes H/M conservan el mismo número.';
      }
      return null;
    }
    final atOrder = widget.existingTests.where(
      (test) => test.displayOrder == order,
    );
    if (atOrder.isNotEmpty &&
        (atOrder.length != 1 || _variantAt(order) == null)) {
      return 'Este número ya corresponde a otra prueba.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final test = widget.existing;
    if (test == null) return;
    _name.text = test.name;
    _protocol.text = test.protocolNotes;
    _order.text = test.displayOrder.toString();
    _step.text = formatMark(test.markStep);
    _minAge.text = test.minAge == 0 ? '' : test.minAge.toString();
    _maxAge.text = test.maxAge == 120 ? '' : test.maxAge.toString();
    _unit = test.unit;
    _direction = test.betterDirection;
    _category = test.category;
    _maxAttempts.text = test.maxAttempts.toString();
    _distance.text = test.distanceMeters?.toString() ?? '';
    _continuous2000mProtocol = test.measurementProtocol == 'run_2000m_v1';
    _retryPolicy = test.retryPolicy;
  }

  @override
  void dispose() {
    _name.dispose();
    _protocol.dispose();
    _order.dispose();
    _step.dispose();
    _minAge.dispose();
    _maxAge.dispose();
    _maxAttempts.dispose();
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Añadir prueba' : 'Editar prueba'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la prueba',
                ),
                maxLength: 120,
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Escribe al menos 3 caracteres.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'A quién corresponde',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('Hombres y mujeres'),
                  ),
                  DropdownMenuItem(value: 'men', child: Text('Solo hombres')),
                  DropdownMenuItem(value: 'women', child: Text('Solo mujeres')),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 6),
              const Text(
                'H/M son columnas del baremo oficial; no se deducen automáticamente de la identidad del perfil.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minAge,
                decoration: const InputDecoration(
                  labelText: 'Edad desde (opcional)',
                  helperText: 'Vacío: cualquier edad',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _maxAge,
                decoration: const InputDecoration(
                  labelText: 'Edad hasta (opcional)',
                  helperText: 'Vacío: sin límite de edad',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                decoration: const InputDecoration(
                  labelText: 'Número de ejercicio',
                  helperText: 'H y M comparten número si son variantes del mismo ejercicio.',
                ),
                keyboardType: TextInputType.number,
                validator: _validateOrder,
              ),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Qué se registra'),
                items: const [
                  DropdownMenuItem(
                    value: 'repetitions',
                    child: Text('Repeticiones'),
                  ),
                  DropdownMenuItem(
                    value: 'seconds',
                    child: Text('Tiempo en segundos'),
                  ),
                  DropdownMenuItem(
                    value: 'meters',
                    child: Text('Distancia en metros'),
                  ),
                ],
                onChanged: (value) => setState(() => _unit = value ?? _unit),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'Mejor resultado'),
                items: const [
                  DropdownMenuItem(
                    value: 'higher',
                    child: Text('Marca más alta'),
                  ),
                  DropdownMenuItem(
                    value: 'lower',
                    child: Text('Marca más baja'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _direction = value ?? _direction),
              ),
              if (_unit == 'seconds' && _direction == 'lower') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _distance,
                  decoration: const InputDecoration(
                    labelText: 'Distancia oficial en metros (si aplica)',
                    helperText: 'Para carrera de 2 km, indica 2000.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (raw) {
                    if (raw == null || raw.trim().isEmpty) {
                      return _continuous2000mProtocol
                          ? 'Indica 2.000 m para este protocolo.'
                          : null;
                    }
                    final value = int.tryParse(raw.trim());
                    if (_continuous2000mProtocol && value != 2000) {
                      return 'El protocolo seleccionado exige 2.000 m.';
                    }
                    return value == null || value < 1 || value > 100000
                        ? 'Indica una distancia entre 1 y 100.000 m.'
                        : null;
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _continuous2000mProtocol,
                  title: const Text('Carrera continua de 2.000 m'),
                  subtitle: const Text(
                    'Medición cronometrada compatible con el módulo de carrera 2 km. Confirma que el protocolo oficial corresponde.',
                  ),
                  onChanged: (value) =>
                      setState(() => _continuous2000mProtocol = value ?? false),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _step,
                decoration: const InputDecoration(
                  labelText: 'Resolución de la marca',
                  hintText:
                      'Ej.: 0,1 para décimas; 1 para segundos o repeticiones',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    (double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) <= 0
                    ? 'Introduce una resolución positiva.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _retryPolicy,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Repetición de intentos',
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Un intento')),
                  DropdownMenuItem(
                    value: 'invalid_only',
                    child: Text('Repetir solo tras un intento nulo'),
                  ),
                  DropdownMenuItem(
                    value: 'always',
                    child: Text('Varios intentos; cuenta la mejor marca'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _retryPolicy = value ?? _retryPolicy),
              ),
              if (_retryPolicy != 'none')
                TextFormField(
                  controller: _maxAttempts,
                  decoration: const InputDecoration(
                    labelText: 'Número máximo de intentos',
                    helperText: 'Entre 2 y 5, según la convocatoria.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (raw) {
                    final value = int.tryParse(raw ?? '');
                    return value == null || value < 2 || value > 5
                        ? 'Indica entre 2 y 5 intentos.'
                        : null;
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _protocol,
                decoration: const InputDecoration(
                  labelText: 'Cómo se realiza y valida',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Describe el protocolo en al menos 10 caracteres.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          final minAge = _minAge.text.trim().isEmpty
              ? 0
              : int.tryParse(_minAge.text.trim());
          final maxAge = _maxAge.text.trim().isEmpty
              ? 120
              : int.tryParse(_maxAge.text.trim());
          if (minAge == null ||
              maxAge == null ||
              minAge < 0 ||
              maxAge > 120 ||
              minAge > maxAge) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Revisa las edades de la prueba.')),
            );
            return;
          }
          Navigator.of(context).pop(
            AdminProgramTest(
              id: widget.existing?.id ?? '',
              code: widget.existing?.code ?? _slug(_name.text),
              name: _name.text.trim(),
              unit: _unit,
              betterDirection: _direction,
              protocolNotes: _protocol.text.trim(),
              definitionVersion: widget.existing?.definitionVersion ?? 1,
              category: _category,
              groupCode:
                  widget.existing?.groupCode ??
                  (_variantAt(int.parse(_order.text))?.groupCode ??
                      'exercise_${_order.text}'),
              displayOrder: int.parse(_order.text),
              markStep: double.parse(_step.text.replaceAll(',', '.')),
              minAge: minAge,
              maxAge: maxAge,
              maxAttempts: _retryPolicy == 'none'
                  ? 1
                  : int.parse(_maxAttempts.text),
              retryPolicy: _retryPolicy,
              distanceMeters:
                  _unit == 'seconds' &&
                      _direction == 'lower' &&
                      _distance.text.trim().isNotEmpty
                  ? int.parse(_distance.text.trim())
                  : null,
              measurementProtocol:
                  _unit == 'seconds' &&
                      _direction == 'lower' &&
                      _continuous2000mProtocol
                  ? 'run_2000m_v1'
                  : null,
            ),
          );
        },
        child: Text(
          widget.existing == null ? 'Guardar prueba' : 'Guardar cambios',
        ),
      ),
    ],
  );
}

String _slug(String name) {
  var value = name.trim().toLowerCase();
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  for (final entry in accents.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  value = value
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (value.length > 64) {
    value = value.substring(0, 64).replaceFirst(RegExp(r'_+$'), '');
  }
  return value.length >= 3 ? value : 'test_$value';
}
