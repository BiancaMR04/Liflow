import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final DateTime anchorDate;
  final int basePage;
  final int selectedPage;
  final PageController controller;
  final String Function(DateTime date) weekdayLabel;
  final bool Function(DateTime date) isToday;
  final ValueChanged<int> onPageChanged;

  const DaySelector({
    super.key,
    required this.anchorDate,
    required this.basePage,
    required this.selectedPage,
    required this.controller,
    required this.weekdayLabel,
    required this.isToday,
    required this.onPageChanged,
  });

  DateTime _dateForPage(int page) {
    return anchorDate.add(Duration(days: page - basePage));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 104,
      child: PageView.builder(
        controller: controller,
        onPageChanged: onPageChanged,
        itemBuilder: (context, page) {
          final date = _dateForPage(page);
          final selected = page == selectedPage;
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
              onTap: () => onPageChanged(page),
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
