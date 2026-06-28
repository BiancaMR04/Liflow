import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final List<DateTime> dates;
  final int selectedIndex;
  final PageController controller;
  final String Function(DateTime date) weekdayLabel;
  final bool Function(DateTime date) isToday;
  final ValueChanged<int> onIndexChanged;

  const DaySelector({
    super.key,
    required this.dates,
    required this.selectedIndex,
    required this.controller,
    required this.weekdayLabel,
    required this.isToday,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 104,
      child: PageView.builder(
        controller: controller,
        itemCount: dates.length,
        onPageChanged: onIndexChanged,
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = index == selectedIndex;
          final today = isToday(date);

          final bg = selected
              ? theme.colorScheme.primaryContainer
              : (today
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.surfaceContainerLowest);

          final fg = selected
              ? theme.colorScheme.onPrimaryContainer
              : (today
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurface);

          return Center(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onIndexChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 86 : 78,
                height: selected ? 86 : 78,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: selected ? 1.4 : 1.0,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayLabel(date),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          date.day.toString().padLeft(2, '0'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
