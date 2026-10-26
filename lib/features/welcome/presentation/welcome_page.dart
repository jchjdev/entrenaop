import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';

enum WelcomeDestination {
  tools('/tools'),
  training('/home'),
  trainer('/profile/trainer');

  const WelcomeDestination(this.route);
  final String route;
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onChoose,
    required this.onContinueForNow,
    this.onBack,
  });

  final Future<void> Function(WelcomeDestination destination) onChoose;
  final ValueChanged<WelcomeDestination> onContinueForNow;
  final VoidCallback? onBack;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  WelcomeDestination? _saving, _failed;

  Future<void> _choose(WelcomeDestination destination) async {
    if (_saving != null) return;
    setState(() {
      _saving = destination;
      _failed = null;
    });
    try {
      await widget.onChoose(destination);
    } catch (_) {
      if (mounted) setState(() => _failed = destination);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (widget.onBack != null)
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: _saving == null ? widget.onBack : null,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      const EntrenaWordmark(width: 152),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 38,
                      height: 4,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¿Por dónde\nempezamos?',
                    style:
                        (largeText
                                ? Theme.of(context).textTheme.headlineSmall
                                : Theme.of(context).textTheme.displaySmall)
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: largeText ? 22 : null,
                              height: 1.07,
                              letterSpacing: -1.1,
                            ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Elige tu primer paso. Todo lo demás seguirá a mano.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: context.visuals.textMuted,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _WelcomeChoice(
                    number: '01',
                    title: 'Usar las herramientas',
                    description: 'Ritmos de carrera y calculadora FAS.',
                    icon: Icons.calculate_outlined,
                    accent: true,
                    busy: _saving == WelcomeDestination.tools,
                    onTap: _saving == null
                        ? () => _choose(WelcomeDestination.tools)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _WelcomeChoice(
                    number: '02',
                    title: 'Empezar a entrenar',
                    description: 'Tus sesiones, preparaciones y planificación.',
                    icon: Icons.fitness_center_outlined,
                    busy: _saving == WelcomeDestination.training,
                    onTap: _saving == null
                        ? () => _choose(WelcomeDestination.training)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _WelcomeChoice(
                    number: '03',
                    title: 'Tengo una invitación',
                    description:
                        'Revisa y acepta el vínculo con tu entrenador.',
                    icon: Icons.person_add_alt_1_outlined,
                    busy: _saving == WelcomeDestination.trainer,
                    onTap: _saving == null
                        ? () => _choose(WelcomeDestination.trainer)
                        : null,
                  ),
                  if (_failed case final destination?) ...[
                    const SizedBox(height: 20),
                    Text(
                      'No hemos podido guardar que ya has visto la bienvenida. '
                      'Puedes reintentarlo o continuar por ahora.',
                      style: TextStyle(color: colors.error, height: 1.4),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving == null
                              ? () => _choose(destination)
                              : null,
                          child: const Text('Reintentar'),
                        ),
                        TextButton(
                          onPressed: _saving == null
                              ? () => widget.onContinueForNow(destination)
                              : null,
                          child: const Text('Continuar por ahora'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _saving == null
                        ? () => _choose(WelcomeDestination.training)
                        : null,
                    child: const Text('Omitir y no volver a mostrar'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Puedes volver a esta pantalla desde tu perfil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.visuals.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
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

class _WelcomeChoice extends StatelessWidget {
  const _WelcomeChoice({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.busy,
    required this.onTap,
    this.accent = false,
  });

  final String number, title, description;
  final IconData icon;
  final bool accent, busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: accent ? context.visuals.surfaceWarm : context.visuals.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: accent
                ? primary.withValues(alpha: 0.5)
                : context.visuals.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!largeText) ...[
                  Column(
                    children: [
                      Icon(icon, color: primary, size: 27),
                      const SizedBox(height: 8),
                      Text(
                        number,
                        style: TextStyle(
                          color: context.visuals.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: context.visuals.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!largeText) ...[
                  const SizedBox(width: 8),
                  if (busy)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.arrow_forward_rounded, size: 20, color: primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
