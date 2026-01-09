import 'package:flutter/material.dart';

import '../../models/activity.dart';
import 'soft_card.dart';
import 'soft_checkbox.dart';

class TaskCard extends StatelessWidget {
  final Activity activity;
  final bool done;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const TaskCard({
    super.key,
    required this.activity,
    required this.done,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      decoration: done ? TextDecoration.lineThrough : null,
      color: done
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );

    final timeStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final description = (activity.description ?? '').trim();
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );

    final time = activity.scheduledTime;
    final hasTime = time != null && time.isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      opacity: done ? 0.72 : 1.0,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SoftCheckbox(value: done, onChanged: (v) => onToggle(v)),
            const SizedBox(width: 10),
            if (hasTime) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: done
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(time, style: timeStyle),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: descriptionStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (activity.reminder['enabled'] == true) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.notifications_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
