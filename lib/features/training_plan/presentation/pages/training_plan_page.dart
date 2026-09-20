import 'package:flutter/material.dart';

class TrainingPlanPage extends StatelessWidget {
  const TrainingPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mi plan'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.route_outlined,
                          color: Color(0xFFFF8A50),
                          size: 38,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Primero necesitamos conocerte mejor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Tu evaluación señala qué prueba necesita atención. La disponibilidad, el tiempo por sesión y el material permitirán convertir ese foco en un plan realista.',
                          style: TextStyle(color: Colors.white70, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _PlanStep(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Evaluación inicial',
                    description: 'Completada y guardada en tu evolución.',
                    complete: true,
                  ),
                  const _PlanStep(
                    icon: Icons.tune_rounded,
                    title: 'Disponibilidad y medios',
                    description:
                        'Siguiente paso: días, duración, fecha objetivo y material.',
                  ),
                  const _PlanStep(
                    icon: Icons.fact_check_outlined,
                    title: 'Reglas deportivas validadas',
                    description:
                        'La planificación no se activará hasta validar cargas y progresiones.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  const _PlanStep({
    required this.icon,
    required this.title,
    required this.description,
    this.complete = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF66BB6A) : Colors.white54;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF141414),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
      ),
    );
  }
}
