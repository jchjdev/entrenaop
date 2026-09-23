import 'package:flutter/material.dart';

/// Maqueta visible para discutir el flujo. No representa una prescripción ni
/// se guarda en la agenda: todavía faltan el reparto real y la calibración.
class RunningWeekPrototypeCard extends StatelessWidget {
  const RunningWeekPrototypeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1D1917),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.science_outlined, color: Color(0xFFFFA477)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Laboratorio · semana de ejemplo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Ejemplo con 3 días totales: 2 de carrera y 1 reservado para fuerza. No está adaptado a tus marcas, no se añade a tu agenda y no puedes registrarlo como realizado.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 12),
            const _PrototypeSession(
              day: 'Día A',
              title: 'Calidad controlada',
              subtitle: '1 sesión de calidad · ritmo por definir',
              details: [
                'Calentamiento progresivo: 10–12 min fáciles.',
                '4 × 2 min a esfuerzo vivo pero controlado; 2 min suaves entre repeticiones.',
                'Vuelta a la calma: 8–10 min fáciles.',
                'Es una propuesta para revisar, no un ritmo de umbral calculado desde el test de 2 km.',
              ],
            ),
            const _PrototypeSession(
              day: 'Día B',
              title: 'Fuerza',
              subtitle: 'Día reservado · contenido pendiente',
              details: [
                'El programa debe reservar tiempo para las pruebas de fuerza.',
                'Ejercicios, volumen y separación respecto a carrera aún no están definidos.',
              ],
            ),
            const _PrototypeSession(
              day: 'Día C',
              title: 'Carrera fácil',
              subtitle: 'Duración ilustrativa · por ajustar',
              details: [
                'Carrera a esfuerzo cómodo, que permita conversar.',
                'La duración se ajustará al historial reciente; esta maqueta no fija minutos ni ritmo.',
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Después: 2 semanas de carga + 1 de descarga. La dosis y los días concretos aún necesitan reglas y validación.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeSession extends StatelessWidget {
  const _PrototypeSession({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final String day;
  final String title;
  final String subtitle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF493024),
        foregroundColor: const Color(0xFFFFB18A),
        child: Text(day.substring(4)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$day · $subtitle'),
      children: [
        for (final detail in details)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('• $detail', style: const TextStyle(height: 1.35)),
            ),
          ),
      ],
    );
  }
}
