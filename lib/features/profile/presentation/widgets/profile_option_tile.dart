import 'package:flutter/material.dart';

/// Conserva el ancho de lectura cuando el texto ampliado necesita más espacio.
class ProfileOptionTile extends StatelessWidget {
  const ProfileOptionTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isThreeLine = false,
    super.key,
  });

  final Widget title;
  final Widget? subtitle, leading, trailing;
  final VoidCallback? onTap;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(260)) {
        return ListTile(
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          onTap: onTap,
          isThreeLine: isThreeLine,
        );
      }
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null || trailing != null) ...[
                IconTheme.merge(
                  data: IconThemeData(
                    color: ListTileTheme.of(context).iconColor,
                  ),
                  child: Row(children: [?leading, const Spacer(), ?trailing]),
                ),
                const SizedBox(height: 12),
              ],
              DefaultTextStyle.merge(
                style:
                    ListTileTheme.of(context).titleTextStyle ??
                    Theme.of(context).textTheme.bodyLarge,
                child: title,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: subtitle!,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
