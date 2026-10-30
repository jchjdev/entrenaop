import 'dart:math' as math;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/running_pace_analysis.dart';
import 'package:workout_core/running_step.dart';

/// Gráfico de consulta compartido por el portal, el modo profesional y el historial.
class RunningPaceChart extends StatefulWidget {
  const RunningPaceChart({super.key, required this.analysis});
  final RunningPaceAnalysis analysis;

  @override
  State<RunningPaceChart> createState() => _RunningPaceChartState();
}

class _RunningPaceChartState extends State<RunningPaceChart> {
  final _horizontal = ScrollController();
  bool _all = false;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  String? _group;
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    if (analysis.samples.isEmpty) return const SizedBox.shrink();
    final all = _all || !analysis.hasEfforts;
    final samples = analysis.samples.where((s) => all || s.effort).toList();
    final summary = RunningPaceSummary(samples);
    final groups = analysis.groups;
    final group =
        groups.where((g) => g.key == _group).firstOrNull ?? groups.firstOrNull;
    final theme = Theme.of(context);
    final actualColor = context.readableAccent(theme.colorScheme.primary);
    final targetColor = context.readableAccent(const Color(0xff38bdf8));
    return Card(
      key: const ValueKey('running-pace-chart'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ritmo por ${all ? 'tramo' : 'serie'}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Series'),
                  selected: !all,
                  onSelected: analysis.hasEfforts
                      ? (_) => setState(() {
                          _all = false;
                          _hover = null;
                        })
                      : null,
                ),
                ChoiceChip(
                  label: const Text('Todos los tramos'),
                  selected: all,
                  onSelected: (_) => setState(() {
                    _all = true;
                    _hover = null;
                  }),
                ),
              ],
            ),
            if (analysis.hasUnclassified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  analysis.hasEfforts
                      ? 'Los tramos sin fase identificada están en Todos los tramos.'
                      : 'Estos registros no distinguen las fases. Se muestran todos los tramos.',
                ),
              ),
            const SizedBox(height: 12),
            if (summary.count == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Todavía no hay tramos completados con tiempo y distancia válidos para mostrar el ritmo.',
                ),
              )
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legend(context, actualColor, 'Ritmo realizado', true),
                  _legend(context, targetColor, 'Rango pautado', false),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'min/km · Más rápido arriba · Toca un punto para ver el tramo',
              ),
              const SizedBox(height: 8),
              _plot(context, samples, actualColor, targetColor, all),
              if (samples.any((s) => s.pace == null))
                const Text(
                  '— Sin ritmo registrado. Los huecos conservan la posición del tramo.',
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _metric(context, 'Ritmo medio', '${_pace(summary.mean!)}/km'),
                  if (summary.count > 1) ...[
                    _metric(
                      context,
                      'Más rápida · ${_label(samples, summary.fastest!, all)}',
                      '${_pace(summary.fastest!.pace!)}/km',
                    ),
                    _metric(
                      context,
                      'Más lenta · ${_label(samples, summary.slowest!, all)}',
                      '${_pace(summary.slowest!.pace!)}/km',
                    ),
                  ],
                  _metric(
                    context,
                    'Con ritmo registrado',
                    '${summary.count} de ${samples.length}',
                  ),
                ],
              ),
            ],
            const Divider(height: 28),
            Text(
              'Regularidad entre series equivalentes',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (group == null)
              const Text(
                'Disponible con dos o más series completadas de la misma distancia, objetivo y recuperación, dentro del mismo bloque.',
              )
            else ...[
              if (groups.length > 1)
                DropdownButtonFormField<String>(
                  key: ValueKey('pace-group-${group.key}'),
                  initialValue: group.key,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Grupo de series',
                  ),
                  items: [
                    for (final g in groups)
                      DropdownMenuItem(
                        value: g.key,
                        child: Text(
                          _groupLabel(g),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _group = value),
                )
              else
                Text(_groupLabel(group)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _metric(
                    context,
                    'Diferencia entre más rápida y más lenta',
                    '${formatPerformanceTime(group.spread)}/km',
                  ),
                  _metric(
                    context,
                    'Última frente a primera',
                    _delta(group.firstLastDelta),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _plot(
    BuildContext context,
    List<RunningPaceSample> samples,
    Color actual,
    Color target,
    bool all,
  ) {
    final values = <double>[
      for (final s in samples) ...[
        if (s.pace != null) s.pace!.toDouble(),
        if (s.hasTarget) ...[s.targetMin!.toDouble(), s.targetMax!.toDouble()],
      ],
    ];
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final margin = math.max(5.0, (high - low) * .12);
    final min = math.max(0.0, low - margin);
    final max = (high + margin).isFinite ? high + margin : high;
    final scale = MediaQuery.textScalerOf(context);
    final height = 210.0 + scale.scale(12) * 2;
    final axisWidth = math.max(52.0, scale.scale(12) * 4.6);
    final textStyle = Theme.of(context).textTheme.labelSmall!;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: axisWidth,
            child: Stack(
              children: [
                for (var i = 0; i < 4; i++)
                  Positioned(
                    top: 8 + (height - 48) * i / 3 - 6,
                    child: Text(
                      _pace(min + (max - min) * i / 3),
                      style: textStyle,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = math.max(52.0, scale.scale(12) * 3.5);
                final width = math.max(
                  constraints.maxWidth,
                  samples.length * slot,
                );
                final step = width / samples.length;
                return Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      key: const ValueKey('pace-horizontal-scroll'),
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ExcludeSemantics(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _PacePainter(
                                      samples: samples,
                                      min: min,
                                      max: max,
                                      actual: actual,
                                      target: target,
                                      grid: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .12),
                                      selected: _hover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            for (var i = 0; i < samples.length; i++)
                              Positioned(
                                left: i * step,
                                top: 0,
                                width: step,
                                bottom: 0,
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hover = i),
                                  onExit: (_) => setState(() => _hover = null),
                                  child: Tooltip(
                                    excludeFromSemantics: true,
                                    message: _description(
                                      samples[i],
                                      '${all ? 'Tramo' : 'Serie'} ${i + 1}',
                                    ),
                                    child: Semantics(
                                      button: true,
                                      label: _description(
                                        samples[i],
                                        '${all ? 'Tramo' : 'Serie'} ${i + 1}',
                                      ),
                                      child: InkWell(
                                        key: ValueKey('pace-point-$i'),
                                        onTap: () => _open(
                                          samples[i],
                                          '${all ? 'Tramo' : 'Serie'} ${i + 1}',
                                        ),
                                        onFocusChange: (focus) => setState(
                                          () => _hover = focus ? i : null,
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Text(
                                              '${i + 1}',
                                              style: textStyle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(RunningPaceSample sample, String title) async {
    final content = _PaceDetail(sample: sample, title: title);
    if (MediaQuery.sizeOf(context).width >= 650) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: SingleChildScrollView(child: content),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(child: content),
        ),
      );
    }
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter({
    required this.samples,
    required this.min,
    required this.max,
    required this.actual,
    required this.target,
    required this.grid,
    this.selected,
  });
  final List<RunningPaceSample> samples;
  final double min, max;
  final Color actual, target, grid;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final bottom = size.height - 40;
    double y(num value) => top + (value - min) / (max - min) * (bottom - top);
    final step = size.width / samples.length;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final dy = top + (bottom - top) * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
    final line = Paint()
      ..color = actual
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    Offset? previous;
    RunningPaceSample? prior;
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i], x = step * (i + .5);
      if (sample.hasTarget) {
        final a = y(sample.targetMin!), b = y(sample.targetMax!);
        final rect = Rect.fromLTRB(
          x - step / 2 + 3,
          a,
          x + step / 2 - 3,
          math.max(a + 2, b),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = target.withValues(alpha: .18),
        );
        canvas.drawLine(
          Offset(rect.left, a),
          Offset(rect.right, a),
          Paint()
            ..color = target
            ..strokeWidth = 1.4,
        );
        canvas.drawLine(
          Offset(rect.left, b),
          Offset(rect.right, b),
          Paint()
            ..color = target
            ..strokeWidth = 1.4,
        );
      }
      final pace = sample.pace;
      if (pace == null) {
        previous = null;
        prior = null;
        canvas.drawLine(
          Offset(x - 4, bottom + 12),
          Offset(x + 4, bottom + 12),
          Paint()
            ..color = grid
            ..strokeWidth = 2,
        );
        continue;
      }
      final point = Offset(x, y(pace));
      if (previous != null &&
          prior?.kind == sample.kind &&
          prior?.review.block == sample.review.block) {
        canvas.drawLine(previous, point, line);
      }
      canvas.drawCircle(
        point,
        selected == i ? 7 : 4.5,
        Paint()..color = actual,
      );
      previous = point;
      prior = sample;
    }
  }

  @override
  bool shouldRepaint(covariant _PacePainter old) =>
      old.samples != samples ||
      old.selected != selected ||
      old.min != min ||
      old.max != max ||
      old.actual != actual ||
      old.target != target ||
      old.grid != grid;
}

class _PaceDetail extends StatelessWidget {
  const _PaceDetail({required this.sample, required this.title});
  final RunningPaceSample sample;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Cerrar detalle del tramo',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(
          '${sample.review.blockName}${sample.review.order == null ? '' : ' · Tramo ${sample.review.order! + 1}'} · ${sample.kind?.label ?? 'Fase sin identificar'}',
        ),
        const Divider(height: 24),
        Text(_description(sample, title)),
        if (sample.review.actual['rpe'] case final num rpe)
          Text('Esfuerzo percibido: $rpe RPE'),
        if (sample.review.status != 'completed')
          Text(switch (sample.review.status) {
            'skipped' => 'Tramo omitido',
            'in_progress' || 'inProgress' => 'Tramo en curso',
            _ => 'Tramo sin completar',
          }),
      ],
    ),
  );
}

Widget _legend(BuildContext context, Color color, String text, bool point) =>
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: point ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text)),
      ],
    );

Widget _metric(BuildContext context, String label, String value) =>
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );

String _pace(num value) {
  final seconds = value.round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _number(num value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);
String _label(
  List<RunningPaceSample> samples,
  RunningPaceSample sample,
  bool all,
) => '${all ? 'tramo' : 'serie'} ${samples.indexOf(sample) + 1}';
String _groupLabel(RunningPaceGroup group) =>
    '${group.samples.length} × ${_number(group.samples.first.review.targets['distance']!)} m · '
    '${_pace(group.samples.first.targetMin!)}–${_pace(group.samples.first.targetMax!)}/km · '
    '${_recoveryLabel(group.samples.first)} · Bloque ${group.samples.first.review.block! + 1}';

String _recoveryLabel(RunningPaceSample sample) => [
  if (sample.review.targets['recoveryTime'] case final num time)
    'Rec. ${formatPerformanceTime(time)}',
  if (sample.review.targets['recoveryDistance'] case final num distance)
    '${_number(distance)} m',
  if (sample.restAfterSeconds case final num rest when rest > 0)
    'desc. ${formatPerformanceTime(rest)}',
  switch (sample.recoveryType) {
    'passive' => 'pasiva',
    'walking' => 'caminando',
    'jogging' => 'trotando',
    _ => 'modalidad sin registrar',
  },
].join(' ');
String _delta(num delta) => delta.abs() < .005
    ? 'Sin diferencia al redondear'
    : '${delta > 0 ? '+' : '−'}${formatPerformanceTime(delta.abs())}/km · ${delta > 0 ? 'más lenta' : 'más rápida'}';

String _description(RunningPaceSample sample, String title) => [
  '$title · ${sample.kind?.label ?? 'Fase sin identificar'}',
  if (sample.pace != null)
    'Ritmo realizado: ${_pace(sample.pace!)}/km'
  else
    'Sin ritmo registrado',
  if (sample.hasTarget)
    'Objetivo: ${_pace(sample.targetMin!)}–${_pace(sample.targetMax!)}/km',
  if (sample.distance != null)
    'Distancia realizada: ${_number(sample.distance!)} m',
  if (sample.duration != null)
    'Tiempo realizado: ${formatPerformanceTime(sample.duration!)}',
  if (sample.review.actual['recoveryTime'] case final num recovery)
    'Recuperación realizada: ${formatPerformanceTime(recovery)}',
  if (sample.review.actual['recoveryDistance'] case final num distance)
    'Distancia de recuperación: ${_number(distance)} m',
  if (sample.review.targets['recoveryTime'] case final num recovery)
    'Recuperación pautada: ${formatPerformanceTime(recovery)}',
  if (sample.restAfterSeconds case final num rest when rest > 0)
    'Descanso pautado: ${formatPerformanceTime(rest)}',
].join('\n');
