import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';
import 'ec_section.dart';

/// One column of an [EcDataTable].
class EcColumn<T> {
  const EcColumn({required this.label, required this.cell, this.numeric = false});
  final String label;
  final Widget Function(T row) cell;
  final bool numeric;
}

/// A dense, themed table with loading (skeleton), empty and error states. Paging and
/// filtering stay in the repository layer; this widget only renders the rows it is given.
class EcDataTable<T> extends StatelessWidget {
  const EcDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.onRowTap,
  });

  final List<EcColumn<T>> columns;
  final List<T> rows;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final ValueChanged<T>? onRowTap;

  @override
  Widget build(BuildContext context) {
    if (error != null) return EcStateMessage.error(error!, onRetry: onRetry);
    if (loading) return const _Skeleton();
    if (rows.isEmpty) return EcStateMessage.empty(emptyTitle, message: emptyMessage);

    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: EcSpace.xl,
            horizontalMargin: EcSpace.lg,
            columns: [
              for (final c in columns) DataColumn(label: Text(c.label), numeric: c.numeric),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  onSelectChanged: onRowTap == null ? null : (_) => onRowTap!(r),
                  cells: [
                    for (final c in columns)
                      DataCell(DefaultTextStyle.merge(style: const TextStyle(fontFeatures: ecTabularFigures), child: c.cell(r))),
                  ],
                ),
            ],
            border: TableBorder(horizontalInside: BorderSide(color: theme.colorScheme.outline)),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.all(EcSpace.lg),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: EcSpace.sm),
              child: Row(
                children: [
                  for (final w in const [3, 2, 2, 1])
                    Expanded(
                      flex: w,
                      child: Container(
                        height: 12,
                        margin: const EdgeInsets.only(right: EcSpace.lg),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(EcRadius.sm)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Monospace identifier (claim ids, key ids, digests), shortened in the middle; the full value
/// is in the tooltip. Plain text on purpose: selectable text would swallow the tap on a table row.
class EcIdText extends StatelessWidget {
  const EcIdText(this.value, {super.key, this.maxLength = 18});
  final String value;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final short = value.length <= maxLength ? value : '${value.substring(0, maxLength - 7)}…${value.substring(value.length - 6)}';
    return Tooltip(
      message: value,
      child: Text(short, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
    );
  }
}
