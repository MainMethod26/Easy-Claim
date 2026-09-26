import 'package:flutter/material.dart';

import '../api/api_exception.dart';

/// User-facing text for any error thrown by a repository call.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is String) return error; // validation text produced by the app itself
  return 'Something went wrong. Please try again.';
}

/// Centered loading indicator with an optional caption.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFFFF5500)),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ]),
        ),
      );
}

/// Error state with a retry button. Never shows raw bodies: only [errorMessage].
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
            ],
          ]),
        ),
      );
}

/// Empty state with an optional action.
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

void showErrorSnack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage(error)), behavior: SnackBarBehavior.floating),
  );
}
