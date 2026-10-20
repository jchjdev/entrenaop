import 'package:flutter/material.dart';

class WorkoutEffortField extends StatelessWidget {
  const WorkoutEffortField({
    super.key,
    required this.label,
    required this.minimum,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.wholeNumbersOnly = true,
    this.compact = false,
    this.emptyText,
  });
  final String label;
  final int minimum;
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;
  final bool wholeNumbersOnly;
  final bool compact;
  final String? emptyText;
  static String _number(double n) =>
      n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  @override
  Widget build(BuildContext context) {
    final control = InputDecorator(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        labelText: compact ? label : null,
        enabled: enabled,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: compact ? ' ' : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null
                  ? emptyText ?? (compact ? '—' : 'Sin registrar')
                  : _number(value!),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 16),
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 16),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: value == null ? emptyText ?? 'Sin registrar' : _number(value!),
      excludeSemantics: true,
      onTap: enabled ? () => _select(context) : null,
      child: InkWell(
        onTap: enabled ? () => _select(context) : null,
        borderRadius: BorderRadius.circular(10),
        child: compact
            ? control
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  control,
                ],
              ),
      ),
    );
  }

  Future<void> _select(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selection = await showModalBottomSheet<(double?,)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                minimum == 0
                    ? 'Repeticiones que aún podrías hacer.'
                    : '1: muy fácil · 10: esfuerzo máximo.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (
                    var step = minimum * 2;
                    step <= 20;
                    step += wholeNumbersOnly ? 2 : 1
                  )
                    ChoiceChip(
                      label: Text(_number(step / 2)),
                      selected: value == step / 2,
                      onSelected: (_) =>
                          Navigator.pop(sheetContext, (step / 2,)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, (null,)),
                child: Text(
                  emptyText == null
                      ? 'No lo sé · Sin registrar'
                      : 'Usar valor común',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection != null) onChanged(selection.$1);
  }
}
