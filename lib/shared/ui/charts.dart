import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact column chart; the bar at [highlightIndex] is drawn in full color.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.color,
    this.highlightIndex,
    this.labels = const [],
    this.height = 64,
    this.onBarTap,
  });

  final List<double> values;
  final Color color;
  final int? highlightIndex;

  /// Optional labels under the chart, spread evenly (e.g. first/middle/last).
  final List<String> labels;
  final double height;
  final ValueChanged<int>? onBarTap;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);
    final muted = color.withValues(alpha: 0.45);
    final empty = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBarTap == null ? null : () => onBarTap!(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxValue <= 0 || values[i] <= 0
                              ? 0.05
                              : math.max(values[i] / maxValue, 0.05),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: values[i] <= 0
                                  ? empty
                                  : i == highlightIndex
                                  ? color
                                  : muted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map(
                  (label) => Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// Labelled horizontal progress bar, used for category breakdowns.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

/// A single bar split into colored segments proportional to their values.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({super.key, required this.segments, this.height = 10});

  final List<(double, Color)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((segment) => segment.$1 > 0).toList();
    final total = visible.fold<double>(0, (sum, segment) => sum + segment.$1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : Row(
                children: [
                  for (final segment in visible)
                    Expanded(
                      flex: math.max(1, (segment.$1 / total * 1000).round()),
                      child: ColoredBox(color: segment.$2),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Color dot, label and value; the legend for [SegmentedBar].
class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
