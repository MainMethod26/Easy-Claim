import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';

/// A titled card section used to group a chart or table on an admin page.
class EcSection extends StatelessWidget {
  const EcSection({super.key, required this.title, required this.child, this.subtitle, this.trailing, this.padded = true});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(EcSpace.lg, EcSpace.lg, EcSpace.lg, EcSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: padded ? const EdgeInsets.fromLTRB(EcSpace.lg, 0, EcSpace.lg, EcSpace.lg) : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Standard page frame for admin pages: page padding, optional header text and vertical rhythm.
class EcPage extends StatelessWidget {
  const EcPage({super.key, required this.children, this.description});
  final List<Widget> children;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(EcSpace.xl),
      children: [
        if (description != null) ...[
          Text(description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: EcSpace.xl),
        ],
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: EcSpace.xl),
          children[i],
        ],
      ],
    );
  }
}

/// Empty / error / loading states with a clear next step (never a blank area).
class EcStateMessage extends StatelessWidget {
  const EcStateMessage({super.key, required this.icon, required this.title, this.message, this.action});

  factory EcStateMessage.empty(String title, {String? message, Widget? action}) =>
      EcStateMessage(icon: Icons.inbox_outlined, title: title, message: message, action: action);

  factory EcStateMessage.error(String message, {VoidCallback? onRetry}) => EcStateMessage(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: message,
        action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
      );

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EcSpace.xxl, horizontal: EcSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: muted),
          const SizedBox(height: EcSpace.md),
          Text(title, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: EcSpace.xs),
            Text(message!, style: theme.textTheme.bodySmall?.copyWith(color: muted), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: EcSpace.lg), action!],
        ],
      ),
    );
  }
}
