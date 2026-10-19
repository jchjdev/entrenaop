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
  });
  final String label;
  final int minimum;
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;
  final bool wholeNumbersOnly;
  final bool compact;
  static String _number(double n) =>
      n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: enabled ? () => _select(context) : null,
        borderRadius: BorderRadius.circular(15),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            helperText: ' ',
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? 'Sin registrar' : _number(value!),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: !enabled ? null : () => _select(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final result = value == null ? 'Sin registrar' : _number(value!);
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text(result)),
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more_rounded, size: 20),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: Text(label)),
                  Flexible(child: Text(result)),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ],
              );
            },
          ),
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
                child: const Text('No lo sé · Sin registrar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection != null) onChanged(selection.$1);
  }
}
