import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entrena_theme.dart';

/// Las decisiones mantienen una lectura compacta también en escritorio.
class EntrenaDialog extends StatelessWidget {
  const EntrenaDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  static const maxWidth = 480.0;
  static const insetPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 24,
  );
  static const contentPadding = EdgeInsets.fromLTRB(24, 20, 24, 24);

  static double contentWidthOf(BuildContext context) {
    final media = MediaQuery.of(context);
    final available =
        media.size.width -
        media.padding.horizontal -
        media.viewInsets.horizontal -
        insetPadding.horizontal;
    return math.max(
      1,
      math.min(maxWidth, available) - contentPadding.horizontal,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    constraints: const BoxConstraints(maxWidth: maxWidth),
    insetPadding: insetPadding,
    contentPadding: contentPadding,
    title: title,
    content: content,
    actions: actions,
  );
}

/// Jerarquía vertical común para decisiones en móvil y con texto ampliado.
class EntrenaDialogActions extends StatelessWidget {
  const EntrenaDialogActions({
    required this.primaryLabel,
    required this.onPrimary,
    this.secondary = const [],
    super.key,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.maxFinite,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          child: Text(primaryLabel, textAlign: TextAlign.center),
        ),
        for (final action in secondary) ...[const SizedBox(height: 10), action],
      ],
    ),
  );
}

/// La pérdida de datos se distingue del acento reservado para avanzar.
abstract final class EntrenaButtonStyles {
  static ButtonStyle destructive(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton.styleFrom(
      foregroundColor: error,
      backgroundColor: error.withValues(alpha: 0.06),
    ).copyWith(
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? context.visuals.outline
              : error.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
