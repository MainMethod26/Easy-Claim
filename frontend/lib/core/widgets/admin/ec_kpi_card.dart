import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';

/// A KPI card: label, one big number, an optional caption (definition or period) and an
/// optional trailing widget (e.g. a status chip). Every KPI shown on an admin dashboard must
/// have a documented definition and database source (docs/admin/METRICS.md); pass the short
/// form of that definition as [caption] so the number is never unexplained.
class EcKpiCard extends StatelessWidget {
  const EcKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        borderRadius: EcRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(EcSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: muted), const SizedBox(width: EcSpace.sm)],
                  Expanded(
                    child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted), overflow: TextOverflow.ellipsis),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: EcSpace.sm),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: ecTabularFigures),
              ),
              if (caption != null) ...[
                const SizedBox(height: EcSpace.xs),
                Text(caption!, style: theme.textTheme.bodySmall?.copyWith(color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A responsive grid of KPI cards: 1 column on phones, 2 on tablets, up to 4 on desktop.
class EcKpiGrid extends StatelessWidget {
  const EcKpiGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w >= 1000 ? 4 : (w >= 560 ? 2 : 1);
        final itemWidth = (w - EcSpace.lg * (columns - 1)) / columns;
        return Wrap(
          spacing: EcSpace.lg,
          runSpacing: EcSpace.lg,
          children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
        );
      },
    );
  }
}
