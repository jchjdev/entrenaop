import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selección de una capacidad ofrecida por el servidor; no calcula derechos.
class TrainerCapacityPicker extends StatefulWidget {
  const TrainerCapacityPicker({
    super.key,
    required this.value,
    required this.capacities,
    required this.enabled,
    required this.onChanged,
  });
  final int value;
  final List<int> capacities;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  @override
  State<TrainerCapacityPicker> createState() => _TrainerCapacityPickerState();
}

class _TrainerCapacityPickerState extends State<TrainerCapacityPicker> {
  late final _text = TextEditingController(text: widget.value.toString());
  final _focus = FocusNode();
  @override
  void didUpdateWidget(covariant TrainerCapacityPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _text.text != widget.value.toString()) {
      _text.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(int value) {
    _text.text = value.toString();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.capacities.indexOf(widget.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Reducir cupo',
          onPressed: widget.enabled && position > 0
              ? () => _pick(widget.capacities[position - 1])
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Expanded(
          child: TextFormField(
            key: const ValueKey('trainer-capacity'),
            controller: _text,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Cupo de alumnos activos',
              helperText:
                  'De ${widget.capacities.first} a ${widget.capacities.last} alumnos',
            ),
            validator: (value) =>
                widget.capacities.contains(int.tryParse(value ?? ''))
                ? null
                : 'Elige un cupo disponible.',
            onChanged: (value) {
              final n = int.tryParse(value);
              widget.onChanged(widget.capacities.contains(n) ? n : null);
            },
          ),
        ),
        IconButton(
          tooltip: 'Ampliar cupo',
          onPressed:
              widget.enabled &&
                  position >= 0 &&
                  position < widget.capacities.length - 1
              ? () => _pick(widget.capacities[position + 1])
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
