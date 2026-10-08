import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/measurement_history.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MeasurementComparisonCard extends StatefulWidget {
  const MeasurementComparisonCard({required this.series, super.key});
  final List<MeasurementSeries> series;

  @override
  State<MeasurementComparisonCard> createState() =>
      _MeasurementComparisonCardState();
}

class _MeasurementComparisonCardState extends State<MeasurementComparisonCard> {
  String? _seriesId;
  String? _currentId;
  String? _previousId;

  @override
  Widget build(BuildContext context) {
    if (widget.series.isEmpty) return const SizedBox.shrink();
    final selected =
        widget.series.where((s) => s.id == _seriesId).firstOrNull ??
        widget.series.first;
    if (_seriesId != selected.id) {
      _seriesId = selected.id;
      _currentId = null;
      _previousId = null;
    }
    final current =
        selected.samples.where((s) => s.id == _currentId).firstOrNull ??
        selected.samples.first;
    _currentId = current.id;
    final earlier = selected.earlierThan(current);
    final previous =
        earlier.where((s) => s.id == _previousId).firstOrNull ??
        earlier.firstOrNull;
    _previousId = previous?.id;
    final progress = previous == null
        ? null
        : selected.compare(previousId: previous.id, currentId: current.id);

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      child: ExpansionTile(
        key: const PageStorageKey('measurement-comparison-expansion'),
        leading: const Icon(Icons.compare_arrows_rounded),
        title: const Text('Comparar marcas'),
        subtitle: const Text('Elige la prueba y dos fechas'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Compara tus mediciones dentro de la misma prueba y versión. Los controles de carrera se muestran por separado.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('measurement-series-$_seriesId'),
            initialValue: _seriesId,
            isExpanded: true,
            isDense: false,
            itemHeight: null,
            decoration: const InputDecoration(labelText: 'Prueba'),
            selectedItemBuilder: (_) => [
              for (final s in widget.series)
                Text(s.test.name, key: ValueKey('selected-test-${s.id}')),
            ],
            items: [
              for (final s in widget.series)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.test.name} · ${s.origin}${widget.series.where((other) => other.test.id == s.test.id && other.origin == s.origin).length > 1 ? ' · ${s.version}' : ''}',
                  ),
                ),
            ],
            onChanged: (id) => setState(() {
              _seriesId = id;
              _currentId = null;
              _previousId = null;
            }),
          ),
          const SizedBox(height: 8),
          Text(selected.origin, style: Theme.of(context).textTheme.bodySmall),
          Tooltip(
            message: 'Versión: ${selected.version}',
            triggerMode: TooltipTriggerMode.tap,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ver versión guardada',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _datePicker(
            label: 'Fecha reciente',
            samples: selected.samples,
            value: current.id,
            onChanged: (id) => setState(() => _currentId = id),
          ),
          const SizedBox(height: 16),
          if (previous != null) ...[
            _datePicker(
              label: 'Comparar con',
              samples: earlier,
              value: previous.id,
              onChanged: (id) => setState(() => _previousId = id),
            ),
            const SizedBox(height: 16),
            _comparison(selected, previous, current, progress!),
          ] else
            Text(
              selected.canCompare
                  ? 'Elige una fecha reciente que tenga una medición anterior.'
                  : 'Necesitas otra medición de esta prueba y versión, en una fecha posterior.',
            ),
        ],
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required List<MeasurementSample> samples,
    required String value,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$_seriesId-$value'),
    initialValue: value,
    isExpanded: true,
    isDense: false,
    itemHeight: null,
    decoration: InputDecoration(labelText: label),
    selectedItemBuilder: (_) => [
      for (final sample in samples)
        Text(
          DateFormat('dd/MM/yyyy · HH:mm').format(sample.completedAt),
          key: ValueKey('selected-date-$label-${sample.id}'),
        ),
    ],
    items: [
      for (final sample in samples)
        DropdownMenuItem(
          value: sample.id,
          child: Text(
            DateFormat('dd/MM/yyyy · HH:mm').format(sample.completedAt),
          ),
        ),
    ],
    onChanged: onChanged,
  );

  Widget _comparison(
    MeasurementSeries series,
    MeasurementSample previous,
    MeasurementSample current,
    AssessmentProgress progress,
  ) {
    final improved = progress.improved;
    final unchanged = progress.unchanged;
    final color = unchanged
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : improved
        ? const Color(0xFF66BB6A)
        : const Color(0xFFFFA726);
    final amount = formatAssessmentDifference(
      progress.favorableDifference.abs(),
      series.test.unit,
    );
    final delta = unchanged
        ? 'Marca mantenida'
        : '${improved ? 'Mejora' : 'Retroceso'} de $amount';
    return EntrenaCard(
      tone: EntrenaCardTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            series.test.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final before = _value('Anterior', series, previous);
              final after = _value('Reciente', series, current);
              return constraints.maxWidth < 360
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [before, const SizedBox(height: 16), after],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: before),
                        const SizedBox(width: 16),
                        Expanded(child: after),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                unchanged
                    ? Icons.trending_flat
                    : improved
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  delta,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            series.test.betterDirection == BetterDirection.lower
                ? 'Menos ${series.test.unit == MarkUnit.repetitions ? 'repeticiones' : 'tiempo'} es favorable.'
                : 'Más ${series.test.unit == MarkUnit.repetitions ? 'repeticiones' : 'tiempo'} es favorable.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const Text('Los resultados completos se conservan en el historial.'),
        ],
      ),
    );
  }

  Widget _value(
    String label,
    MeasurementSeries series,
    MeasurementSample sample,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Text(
        formatAssessmentValue(sample.value, series.test),
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(DateFormat('dd/MM/yyyy · HH:mm').format(sample.completedAt)),
      if (sample.context != null) Text(sample.context!),
    ],
  );
}
