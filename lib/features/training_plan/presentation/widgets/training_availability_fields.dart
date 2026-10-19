import 'package:flutter/material.dart';

/// Edita huecos disponibles. La frecuencia deportiva la decide el servidor.
class TrainingAvailabilityFields extends StatelessWidget {
  const TrainingAvailabilityFields({
    required this.availability,
    required this.onChanged,
    required this.enabled,
    required this.defaultMinutes,
    super.key,
  });

  final Map<String, int> availability;
  final void Function(String, int) onChanged;
  final bool enabled;
  final int defaultMinutes;
  static const _names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var d = 1; d <= 7; d++)
        if ((availability['$d'] ?? 0) > 0) d,
    ];
    final durations = <int, int>{};
    for (final day in days) {
      final value = availability['$day']!;
      durations[value] = (durations[value] ?? 0) + 1;
    }
    final sorted = durations.keys.toList()
      ..sort((a, b) {
        final byCount = durations[b]!.compareTo(durations[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final usual = sorted.firstOrNull ?? defaultMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Indica cuándo podrías entrenar y cuánto tiempo tienes para la sesión completa. El motor puede usar menos días: disponibilidad no significa entrenar todos ellos.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey('available_day_count_${days.length}'),
          initialValue: days.length,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Días disponibles',
            helperText: 'Máximo de días que podrías entrenar.',
          ),
          items: [
            for (var n = 0; n <= 7; n++)
              DropdownMenuItem(
                value: n,
                child: Text(
                  n == 0 ? 'Elige tus días' : '$n ${n == 1 ? 'día' : 'días'}',
                ),
              ),
          ],
          onChanged: !enabled
              ? null
              : (count) {
                  // Conservar los días y excepciones existentes; proponer solo los nuevos.
                  final selected = days.take(count!).toSet();
                  for (final day in const [1, 4, 6, 2, 5, 3, 7]) {
                    if (selected.length >= count) break;
                    selected.add(day);
                  }
                  for (var d = 1; d <= 7; d++) {
                    final minutes = selected.contains(d)
                        ? (availability['$d'] ?? 0) > 0
                              ? availability['$d']!
                              : usual
                        : 0;
                    if ((availability['$d'] ?? 0) != minutes) {
                      onChanged('$d', minutes);
                    }
                  }
                },
        ),
        const SizedBox(height: 16),
        Text(
          'Duración habitual · sesión completa',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Al elegir una duración se aplica a los días marcados. Puedes ajustar excepciones debajo.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ({30, 45, 60, 75, 90, usual}.toList()..sort()))
              ChoiceChip(
                label: Text('$value min'),
                selected:
                    days.isNotEmpty && durations.length == 1 && usual == value,
                onSelected: !enabled || days.isEmpty
                    ? null
                    : (_) {
                        for (final d in days) {
                          onChanged('$d', value);
                        }
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Confirma qué días tienes disponibles'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(_names[d - 1]),
                selected: days.contains(d),
                onSelected: !enabled
                    ? null
                    : (selected) => onChanged('$d', selected ? usual : 0),
              ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Ajustar minutos de un día concreto'),
          children: [
            for (final day in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DropdownButtonFormField<int>(
                  key: ValueKey('minutes_${day}_${availability['$day']}'),
                  initialValue: availability['$day'],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '${_names[day - 1]} · minutos',
                  ),
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
                      DropdownMenuItem(value: minutes, child: Text('$minutes')),
                  ],
                  onChanged: !enabled
                      ? null
                      : (value) => onChanged('$day', value!),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
