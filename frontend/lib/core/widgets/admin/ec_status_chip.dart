import 'package:flutter/material.dart';

import '../../theme/ec_status_colors.dart';
import '../../theme/ec_tokens.dart';

/// The tone family a status belongs to.
enum EcToneKind { neutral, info, success, warning, danger }

/// A status chip: icon + label + tone. Colour is never the only signal (WCAG 1.4.1), so the
/// chip reads correctly in greyscale and for colour-blind users.
class EcStatusChip extends StatelessWidget {
  const EcStatusChip({super.key, required this.label, required this.icon, this.kind = EcToneKind.neutral, this.tooltip});

  final String label;
  final IconData icon;
  final EcToneKind kind;
  final String? tooltip;

  /// Claim lifecycle stage (backend stage names). Stages are neutral/informational on purpose:
  /// colour is reserved for outcomes and alerts.
  factory EcStatusChip.stage(String stage) {
    switch (stage) {
      case 'Paid':
        return EcStatusChip(label: stage, icon: Icons.payments_outlined, kind: EcToneKind.success);
      case 'Decision':
        return EcStatusChip(label: stage, icon: Icons.gavel_outlined, kind: EcToneKind.info);
      case 'Info Needed':
        return EcStatusChip(label: stage, icon: Icons.help_outline, kind: EcToneKind.warning);
      case 'Withdrawn':
      case 'Expired':
        return EcStatusChip(label: stage, icon: Icons.block_outlined);
      case 'Appeal':
        return EcStatusChip(label: stage, icon: Icons.replay_outlined, kind: EcToneKind.warning);
      default:
        return EcStatusChip(label: stage, icon: Icons.radio_button_checked_outlined);
    }
  }

  /// Advisory screening band (NORMAL / ELEVATED / HIGH). Labelled as advisory in the tooltip.
  factory EcStatusChip.band(String band) {
    switch (band) {
      case 'HIGH':
        return const EcStatusChip(label: 'High', icon: Icons.warning_amber_rounded, kind: EcToneKind.danger, tooltip: 'Advisory screening signal — a human decides');
      case 'ELEVATED':
        return const EcStatusChip(label: 'Elevated', icon: Icons.trending_up_rounded, kind: EcToneKind.warning, tooltip: 'Advisory screening signal — a human decides');
      default:
        return const EcStatusChip(label: 'Normal', icon: Icons.check_circle_outline, kind: EcToneKind.success, tooltip: 'Advisory screening signal — a human decides');
    }
  }

  /// ML-DSA-65 decision signature status as returned by /decision/verify.
  factory EcStatusChip.integrity(String status) {
    switch (status) {
      case 'VALID':
        return const EcStatusChip(label: 'Verified', icon: Icons.verified_user_outlined, kind: EcToneKind.success, tooltip: 'ML-DSA-65 signature verifies');
      case 'TAMPERED':
        return const EcStatusChip(label: 'Tampered', icon: Icons.gpp_bad_outlined, kind: EcToneKind.danger, tooltip: 'Decision changed after signing');
      case 'UNSIGNED':
        return const EcStatusChip(label: 'Unsigned', icon: Icons.shield_outlined, kind: EcToneKind.warning, tooltip: 'No signature recorded');
      case 'UNKNOWN_KEY':
        return const EcStatusChip(label: 'Unknown key', icon: Icons.key_off_outlined, kind: EcToneKind.warning, tooltip: 'Signed with a key this deployment does not hold');
      default:
        return EcStatusChip(label: status, icon: Icons.help_outline);
    }
  }

  /// Audit outcome (success / denied / failure).
  factory EcStatusChip.outcome(String outcome) {
    switch (outcome) {
      case 'success':
        return const EcStatusChip(label: 'Success', icon: Icons.check, kind: EcToneKind.success);
      case 'denied':
        return const EcStatusChip(label: 'Denied', icon: Icons.do_not_disturb_on_outlined, kind: EcToneKind.danger);
      default:
        return const EcStatusChip(label: 'Failure', icon: Icons.error_outline, kind: EcToneKind.warning);
    }
  }

  /// Account status (active / disabled / invited).
  factory EcStatusChip.account(String status) {
    switch (status) {
      case 'active':
        return const EcStatusChip(label: 'Active', icon: Icons.circle, kind: EcToneKind.success);
      case 'disabled':
        return const EcStatusChip(label: 'Disabled', icon: Icons.pause_circle_outline);
      default:
        return EcStatusChip(label: status, icon: Icons.schedule_outlined, kind: EcToneKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EcStatusColors.of(context);
    final tone = switch (kind) {
      EcToneKind.neutral => colors.neutral,
      EcToneKind.info => colors.info,
      EcToneKind.success => colors.success,
      EcToneKind.warning => colors.warning,
      EcToneKind.danger => colors.danger,
    };
    final chip = Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: EcSpace.sm, vertical: 3),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(EcRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tone.foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
