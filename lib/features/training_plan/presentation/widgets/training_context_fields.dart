import 'package:flutter/material.dart';

import 'training_equipment_labels.dart';

/// Formulario común de disponibilidad real; no calcula ni reserva dosis.
class TrainingContextFields extends StatelessWidget {
  const TrainingContextFields({
    required this.availability,
    required this.equipment,
    required this.equipmentOptions,
    required this.reportsPain,
    required this.confirmed,
    required this.onAvailability,
    required this.onEquipment,
    required this.onPain,
    required this.onConfirmed,
    this.enabled = true,
    this.defaultMinutes = 60,
    super.key,
  });
  final Map<String, int> availability;
  final Set<String> equipment, equipmentOptions;
  final bool reportsPain, confirmed, enabled;
  final int defaultMinutes;
  final void Function(String, int) onAvailability;
  final void Function(String, bool) onEquipment;
  final ValueChanged<bool> onPain, onConfirmed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Indica el tiempo total para entrenar cada día. Incluye carrera, fuerza, calentamiento y descansos; la app reparte el trabajo.',
      ),
      const SizedBox(height: 16),
      for (var day = 1; day <= 7; day++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              final dayField = CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  const [
                    'Lunes',
                    'Martes',
                    'Miércoles',
                    'Jueves',
                    'Viernes',
                    'Sábado',
                    'Domingo',
                  ][day - 1],
                ),
                value: (availability['$day'] ?? 0) > 0,
                onChanged: enabled
                    ? (value) =>
                          onAvailability('$day', value! ? defaultMinutes : 0)
                    : null,
              );
              final active = (availability['$day'] ?? 0) > 0;
              final minutesField = active
                  ? SizedBox(
                      width: stack ? 200 : 125,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('minutes_${day}_${availability['$day']}'),
                        initialValue: availability['$day'],
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Minutos'),
                        items: [
                          for (final minutes in ({
                            15,
                            20,
                            25,
                            30,
                            45,
                            60,
                            75,
                            90,
                            120,
                            150,
                            180,
                            availability['$day']!,
                          }.toList()..sort()))
                            DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes'),
                            ),
                        ],
                        onChanged: enabled
                            ? (value) => onAvailability('$day', value!)
                            : null,
                      ),
                    )
                  : null;
              return stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        dayField,
                        if (minutesField != null) const SizedBox(height: 12),
                        ?minutesField,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: dayField),
                        if (minutesField != null) const SizedBox(width: 12),
                        ?minutesField,
                      ],
                    );
            },
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Material disponible',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Marca solo el material al que realmente tienes acceso. Puedes añadirlo y retirarlo aquí o desde Perfil.',
      ),
      const SizedBox(height: 8),
      if (equipment.isEmpty)
        const Text('Sin material confirmado.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final code in (equipment.toList()..sort()))
              InputChip(
                label: Text(performanceEquipmentLabel(code)),
                deleteButtonTooltipMessage: 'Retirar material',
                onDeleted: enabled ? () => onEquipment(code, false) : null,
              ),
          ],
        ),
      _EquipmentPicker(
        selected: equipment,
        options: equipmentOptions,
        enabled: enabled,
        onChanged: onEquipment,
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Estos datos representan mi situación actual'),
        value: confirmed,
        onChanged: enabled ? onConfirmed : null,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Tengo molestias o una limitación que afecta al entrenamiento',
        ),
        value: reportsPain,
        onChanged: enabled ? onPain : null,
      ),
    ],
  );
}

class _EquipmentPicker extends StatefulWidget {
  const _EquipmentPicker({
    required this.selected,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });
  final Set<String> selected, options;
  final bool enabled;
  final void Function(String, bool) onChanged;
  @override
  State<_EquipmentPicker> createState() => _EquipmentPickerState();
}

class _EquipmentPickerState extends State<_EquipmentPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final codes = {...widget.options, ...widget.selected}.toList()
      ..sort(
        (a, b) =>
            performanceEquipmentLabel(a)
                .compareTo(performanceEquipmentLabel(b)),
      );
    final matches = codes.where(
      (code) =>
          performanceEquipmentLabel(code)
              .toLowerCase()
              .contains(_query.toLowerCase()),
    );
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Añadir o cambiar material'),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        TextField(
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Buscar material',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final code in matches)
                FilterChip(
                  label: Text(performanceEquipmentLabel(code)),
                  selected: widget.selected.contains(code),
                  onSelected: widget.enabled
                      ? (selected) => widget.onChanged(code, selected)
                      : null,
                ),
            ],
          ),
        ),
        if (matches.isEmpty)
          const Text('No hay material con ese nombre en el catálogo.'),
      ],
    );
  }
}
