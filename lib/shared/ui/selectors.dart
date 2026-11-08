import 'package:flutter/material.dart';

/// Rounded selectable pill; filled with the primary color when selected.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of pills.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Scrollable strip of the last [monthCount] months, newest on the right.
class MonthStrip extends StatelessWidget {
  const MonthStrip({
    super.key,
    required this.month,
    required this.year,
    required this.onChanged,
    this.monthCount = 24,
  });

  final int month;
  final int year;
  final void Function(int month, int year) onChanged;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      for (var offset = 0; offset < monthCount; offset++)
        DateTime(now.year, now.month - offset),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = months[index];
          final selected = date.month == month && date.year == year;
          final showYear = selected || date.month == 1 || index == 0;
          return PillChip(
            label: showYear ? 'T${date.month}/${date.year}' : 'T${date.month}',
            selected: selected,
            onTap: () => onChanged(date.month, date.year),
          );
        },
      ),
    );
  }
}

/// "‹ 2026 ›" year switcher.
class YearStepper extends StatelessWidget {
  const YearStepper({super.key, required this.year, required this.onChanged});

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canGoNext = year < DateTime.now().year;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onChanged(year - 1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Năm trước',
        ),
        Text(
          'Năm $year',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: canGoNext ? () => onChanged(year + 1) : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Năm sau',
        ),
      ],
    );
  }
}
