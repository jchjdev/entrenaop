import 'package:flutter/material.dart';

/// Distribución intercambiable: el contenido puede desplazarse sin mover la acción.
class WorkoutExecutionFrame extends StatelessWidget {
  const WorkoutExecutionFrame({
    super.key,
    required this.child,
    required this.actions,
    this.fillViewport = false,
    this.header,
  });
  final Widget child, actions;
  final bool fillViewport;
  final Widget? header;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        ?header,
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: fillViewport
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (viewport.maxHeight - 20).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      // Solo el contenido con foto flexible solicita esta
                      // medida: crece con el hueco real, pero puede desplazarse
                      // si campos, teclado o texto ampliado necesitan más alto.
                      child: IntrinsicHeight(child: child),
                    )
                  : child,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * .45),
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: actions,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class WorkoutExerciseHeader extends StatelessWidget {
  const WorkoutExerciseHeader({
    super.key,
    required this.name,
    required this.position,
    required this.onTechnique,
    this.imageUrl,
    this.expandImage = false,
  });
  final String name, position;
  final String? imageUrl;
  final bool expandImage;
  final VoidCallback onTechnique;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        position,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: const Color(0xFFFFA06F)),
      ),
      const SizedBox(height: 5),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Técnica del ejercicio',
            onPressed: onTechnique,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      if (imageUrl?.trim().isNotEmpty == true)
        if (expandImage)
          Expanded(child: _buildImage(context))
        else
          _buildImage(context),
    ],
  );

  Widget _buildImage(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 128),
      child: Semantics(
        button: true,
        label: 'Ver técnica de $name',
        child: InkWell(
          onTap: onTechnique,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: const Color(0xFF15191E),
              child: Image.network(
                imageUrl!,
                // Base para medir el contenido; el padre amplía esta altura
                // con el espacio real que dejan el reloj y las acciones.
                height: 128,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 76,
                  child: Center(
                    child: Icon(Icons.fitness_center_rounded, size: 36),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class WorkoutRestPanel extends StatelessWidget {
  const WorkoutRestPanel({
    super.key,
    required this.seconds,
    required this.canSkip,
    required this.onSkip,
    required this.nextName,
    required this.nextTarget,
    this.nextImageUrl,
    required this.onNextTechnique,
  });
  final int seconds;
  final bool canSkip;
  final VoidCallback onSkip, onNextTechnique;
  final String nextName, nextTarget;
  final String? nextImageUrl;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Text(
        canSkip ? 'Descanso' : 'Siguiente minuto',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
      ),
      if (canSkip)
        TextButton(onPressed: onSkip, child: const Text('Saltar descanso')),
      const SizedBox(height: 20),
      const Text(
        'A CONTINUACIÓN',
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.1,
          color: Colors.white60,
        ),
      ),
      const SizedBox(height: 10),
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onNextTechnique,
        leading: nextImageUrl == null
            ? const Icon(Icons.fitness_center_rounded)
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  nextImageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.fitness_center_rounded),
                ),
              ),
        title: Text(
          nextName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(nextTarget),
        trailing: const Icon(Icons.info_outline_rounded),
      ),
    ],
  );
}
