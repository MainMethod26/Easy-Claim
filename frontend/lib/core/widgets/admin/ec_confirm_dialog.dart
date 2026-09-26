import 'package:flutter/material.dart';

import '../../theme/ec_tokens.dart';

/// Confirmation for sensitive administrative actions (disable an account, suspend an insurer,
/// change a role). A reason is required and returned to the caller, which sends it to the
/// backend so it lands in the audit trail. This is a UX guard only — the server still
/// authorises and validates every request.
Future<String?> showEcConfirmWithReason(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  int minReasonLength = 5,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setState) {
          final ok = controller.text.trim().length >= minReasonLength;
          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: EcSpace.lg),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(labelText: 'Reason (recorded in the audit log)', helperText: 'At least $minReasonLength characters'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                style: destructive ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error) : null,
                onPressed: ok ? () => Navigator.of(context).pop(controller.text.trim()) : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}
