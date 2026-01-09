import 'package:flutter/material.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(padding: padding, child: child);

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLowest,
      shape: theme.cardTheme.shape,
      child: InkWell(
        borderRadius:
            (theme.cardTheme.shape as RoundedRectangleBorder?)?.borderRadius
                as BorderRadius? ??
            BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
