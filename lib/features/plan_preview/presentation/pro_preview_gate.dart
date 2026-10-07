import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// La simulación evita montar pantallas que calculan o publican programas.
/// Los derechos reales deberán verificarse también en el servidor.
class ProPreviewGate extends StatelessWidget {
  const ProPreviewGate({required this.builder, super.key});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => PlanPreviewScope.isFree(context)
      ? const ProPreviewPage()
      : builder(context);
}

class ProPreviewPage extends StatelessWidget {
  const ProPreviewPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EntrenaOP Pro')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: EntrenaCard(
            tone: EntrenaCardTone.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tu programa, adaptado a ti',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prepara tu objetivo con entrenamientos que utilizan tus marcas, tu disponibilidad y tu material.',
                ),
                const SizedBox(height: 18),
                const Text(
                  '• Planificación de tus entrenamientos.\n• Ajustes a partir de resultados y contexto.\n• Continuidad del programa y seguimiento de su evolución.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Los programas adaptativos forman parte de Pro. La contratación todavía no está disponible.',
                ),
                if (PlanPreviewScope.stateOf(context)?.available ?? false) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/profile'),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Cambiar vista de prueba en Perfil'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
