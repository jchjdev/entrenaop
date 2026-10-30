import 'package:flutter/material.dart';

/// El espacio de consulta tiene su propia densidad; no reduce la escala de
/// accesibilidad del teléfono ni altera el tema de los portales de escritorio.
ThemeData coachMobileTheme(ThemeData base) => base.copyWith(
  textTheme: base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 21),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 20),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
  ),
  appBarTheme: base.appBarTheme.copyWith(
    titleTextStyle: base.textTheme.titleLarge?.copyWith(fontSize: 20),
    toolbarHeight: 56,
    titleSpacing: 16,
  ),
  cardTheme: base.cardTheme.copyWith(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: base.colorScheme.outlineVariant),
    ),
  ),
  listTileTheme: base.listTileTheme.copyWith(
    titleTextStyle: base.textTheme.titleMedium?.copyWith(fontSize: 15),
    subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
      color: base.colorScheme.onSurfaceVariant,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),
  navigationBarTheme: base.navigationBarTheme.copyWith(
    height: 68,
    labelTextStyle: WidgetStatePropertyAll(
      base.textTheme.labelMedium?.copyWith(fontSize: 12),
    ),
  ),
);

class CoachSectionHeading extends StatelessWidget {
  const CoachSectionHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: LayoutBuilder(
      builder: (context, size) {
        final titleWidget = Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        );
        final link = action == null
            ? null
            : TextButton(onPressed: onAction, child: Text(action!));
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            size.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, ?link],
          );
        }
        return Row(
          children: [
            Expanded(child: titleWidget),
            ?link,
          ],
        );
      },
    ),
  );
}

class CoachNavigationCard extends StatelessWidget {
  const CoachNavigationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.unread = 0,
    this.initials,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final int unread;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: initials == null
                        ? Icon(icon, size: 20)
                        : Text(initials!, style: theme.textTheme.labelLarge),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
