import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';

/// Marco visual comun para acceso y alta.
///
/// Centraliza marca, fondo y jerarquia para que las pantallas de autenticacion
/// no repliquen decoracion ni se separen del sistema visual de la aplicacion.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.footer,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    children: [
                      const Expanded(child: _BrandPanel()),
                      Expanded(
                        child: _ScrollableForm(
                          title: title,
                          subtitle: subtitle,
                          footer: footer,
                          onBack: onBack,
                          child: child,
                        ),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          const EntrenaWordmark(width: 224),
                          const SizedBox(height: 30),
                          _AuthFormPanel(
                            title: title,
                            subtitle: subtitle,
                            footer: footer,
                            onBack: onBack,
                            child: child,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableForm extends StatelessWidget {
  const _ScrollableForm({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _AuthFormPanel(
            title: title,
            subtitle: subtitle,
            footer: footer,
            onBack: onBack,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return EntrenaCard(
      tone: EntrenaCardTone.neutral,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                tooltip: 'Volver al acceso',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: context.visuals.textMuted,
            ),
          ),
          const SizedBox(height: 30),
          child,
          if (footer != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EntrenaWordmark(width: 320),
              const SizedBox(height: 46),
              Text(
                'Tu preparación, más clara.',
                style: textTheme.headlineLarge?.copyWith(fontSize: 44),
              ),
              const SizedBox(height: 16),
              Text(
                'Objetivos, entrenamientos y evolución en un recorrido que te dice qué importa ahora.',
                style: textTheme.bodyLarge?.copyWith(
                  color: context.visuals.textMuted,
                  fontSize: 18,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              const _BrandPoint(
                icon: Icons.event_available_outlined,
                text: 'Tu semana de entrenamiento, en un vistazo',
              ),
              const SizedBox(height: 14),
              const _BrandPoint(
                icon: Icons.insights_rounded,
                text: 'Tus marcas y tu evolución, con contexto',
              ),
              const SizedBox(height: 14),
              const _BrandPoint(
                icon: Icons.flag_outlined,
                text: 'Un recorrido ordenado hacia tu objetivo',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.visuals.accentSoft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: context.visuals.outlineStrong),
          ),
          child: Icon(icon, size: 21, color: EntrenaTheme.brandOrangeLight),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: -220,
            left: -170,
            child: _Glow(
              size: 560,
              color: EntrenaTheme.brandOrange.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            right: -210,
            bottom: -260,
            child: _Glow(
              size: 620,
              color: EntrenaTheme.brandOrangeLight.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            left: -60,
            top: 160,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 360,
                height: 2,
                color: EntrenaTheme.brandOrange.withValues(alpha: 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
