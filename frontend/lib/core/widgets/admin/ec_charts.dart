import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';

/// One labelled count for a category chart (e.g. claims per stage).
class EcBarDatum {
  const EcBarDatum(this.label, this.value);
  final String label;
  final num value;
}

/// Category comparison as a bar chart (bars read faster than pies/donuts; baseline at 0).
/// Built from plain widgets, no chart dependency. Bars use the single brand accent, and the
/// exact value is printed above each bar, so reading it never depends on colour or estimation.
class EcBarChart extends StatelessWidget {
  const EcBarChart({super.key, required this.data, this.height = 200});
  final List<EcBarDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxV = data.isEmpty ? 0.0 : data.map((d) => d.value.toDouble()).reduce((a, b) => a > b ? a : b);
    const labelH = 18.0, valueH = 18.0;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline))),
              child: LayoutBuilder(builder: (context, box) {
                // Measured, not precomputed: the tallest bar plus its value label fills the plot.
                final barArea = (box.maxHeight - valueH).clamp(0.0, double.infinity);
                return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in data)
                    Expanded(
                      child: Semantics(
                        label: '${d.label}: ${d.value}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: valueH,
                              child: Text('${d.value}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: ecTabularFigures)),
                            ),
                            Container(
                              width: 22,
                              height: maxV <= 0 ? 0 : (d.value / maxV) * barArea,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(EcRadius.sm)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
              }),
            ),
          ),
          const SizedBox(height: EcSpace.sm),
          SizedBox(
            height: labelH,
            child: Row(children: [
              for (final d in data)
                Expanded(
                  child: Text(d.label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// A horizontal proportion bar with a legend (use instead of a donut): each segment is
/// labelled with its name and count, so the reading never depends on colour.
class EcProportionBar extends StatelessWidget {
  const EcProportionBar({super.key, required this.segments});
  final List<({String label, int value, Color color, IconData icon})> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<int>(0, (s, e) => s + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(EcRadius.pill),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? Container(color: theme.colorScheme.outline)
                : Row(
                    children: [
                      for (final s in segments)
                        if (s.value > 0) Expanded(flex: s.value, child: Container(color: s.color)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: EcSpace.md),
        Wrap(
          spacing: EcSpace.lg,
          runSpacing: EcSpace.sm,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 14, color: s.color),
                  const SizedBox(width: 4),
                  Text('${s.label} ', style: theme.textTheme.bodySmall),
                  Text(
                    total == 0 ? '0' : '${s.value} (${(s.value * 100 / total).round()}%)',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: ecTabularFigures),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
