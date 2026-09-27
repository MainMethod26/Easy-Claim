import 'package:flutter/material.dart';

import '../core/realtime/live_refresh.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/ec_status_colors.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/admin/ec_status_chip.dart';
import '../core/widgets/ec_tap_target.dart';
import '../data/models/consent_models.dart';
import '../data/repositories/consent_repository.dart';
import '../screens/consent_form_screen.dart';

// Shared pieces for POPIA consent forms: status and seal chips, the read-only form dialog used
// by staff, the optional-reason dialog used by customers, and the Home attention banner.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "27 Sep 2026, 14:05" in local time, or an em dash.
String formatConsentDate(DateTime? t) {
  if (t == null) return '—';
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Customer-facing name of a subject when the detail label is not loaded.
String consentSubjectText(Consent c) => c.subjectLabel ?? (c.isClaim ? 'a claim' : 'a policy request');

/// A status badge (icon + label + tone) like EcStatusChip, but the label wraps instead of
/// overflowing on a phone with large text. Place it where the width is bounded (Wrap, Column,
/// Expanded), not directly in an unbounded Row.
class ConsentBadge extends StatelessWidget {
  const ConsentBadge({super.key, required this.label, required this.icon, this.kind = EcToneKind.neutral, this.tooltip});
  final String label;
  final IconData icon;
  final EcToneKind kind;
  final String? tooltip;

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
    final badge = Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: EcSpace.sm, vertical: 3),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(EcRadius.md)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: tone.foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip!, child: badge);
  }
}

/// Where a claim's or policy request's POPIA mandate stands, as staff and customers see it.
/// `superseded` forms and subjects without a form have no state (null).
enum MandateState {
  awaiting('Awaiting POPIA mandate', 'Consent form to sign', Icons.hourglass_top_rounded, EcToneKind.warning),
  reading('Customer is reading', 'Consent form to sign', Icons.visibility_outlined, EcToneKind.info),
  signed('Mandate signed', 'Signed', Icons.task_alt, EcToneKind.success),
  rejected('Mandate rejected', 'You declined', Icons.do_not_disturb_on_outlined, EcToneKind.danger),
  withdrawn('Consent withdrawn', 'You withdrew consent', Icons.undo, EcToneKind.danger);

  const MandateState(this.staffLabel, this.customerLabel, this.icon, this.kind);
  final String staffLabel;
  final String customerLabel;
  final IconData icon;
  final EcToneKind kind;

  /// Maps a backend status (+ the customer's first-open time) to a state.
  static MandateState? of(String? status, DateTime? viewedAt) => switch (status) {
        ConsentStatus.pending => viewedAt == null ? awaiting : reading,
        'viewed' => reading,
        ConsentStatus.signed => signed,
        ConsentStatus.declined => rejected,
        ConsentStatus.withdrawn => withdrawn,
        _ => null,
      };
}

/// The one mandate indicator used everywhere (queues, claim file, policy requests, customer cards):
/// "Awaiting POPIA mandate" (amber), "Customer is reading" (blue), "Mandate signed" (green),
/// "Mandate rejected" / "Consent withdrawn" (red). With [customer] the wording is the customer's
/// own ("Consent form to sign", "Signed", "You declined", "You withdrew consent"). Nothing is shown
/// without a form unless [noneLabel] is given. Icon + text, never colour alone; the label wraps.
class MandateBadge extends StatelessWidget {
  const MandateBadge({super.key, required this.status, this.viewedAt, this.customer = false, this.noneLabel});
  final String? status;
  final DateTime? viewedAt;
  final bool customer;
  final String? noneLabel;

  /// The text a badge shows for these values (null = no badge).
  static String? labelFor(String? status, DateTime? viewedAt, {bool customer = false}) {
    final s = MandateState.of(status, viewedAt);
    return s == null ? null : (customer ? s.customerLabel : s.staffLabel);
  }

  @override
  Widget build(BuildContext context) {
    final s = MandateState.of(status, viewedAt);
    if (s == null) {
      if (noneLabel == null || status == ConsentStatus.superseded) return const SizedBox.shrink();
      return ConsentBadge(key: const Key('mandate-badge'), label: noneLabel!, icon: Icons.remove_circle_outline);
    }
    // Customers see one "to sign" state whether or not they already opened the form.
    final toSign = customer && (s == MandateState.awaiting || s == MandateState.reading);
    final label = customer ? s.customerLabel : s.staffLabel;
    final tip = !customer && s == MandateState.reading && viewedAt != null ? 'Opened ${formatConsentDate(viewedAt)}' : null;
    return ConsentBadge(
      key: const Key('mandate-badge'),
      label: label,
      icon: toSign ? Icons.draw_outlined : s.icon,
      kind: toSign ? EcToneKind.warning : s.kind,
      tooltip: tip,
    );
  }
}

class ConsentStatusChip extends StatelessWidget {
  const ConsentStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => switch (status) {
        ConsentStatus.signed => const ConsentBadge(label: 'Signed', icon: Icons.task_alt, kind: EcToneKind.success),
        ConsentStatus.declined => const ConsentBadge(label: 'Declined', icon: Icons.do_not_disturb_on_outlined, kind: EcToneKind.danger),
        ConsentStatus.withdrawn => const ConsentBadge(label: 'Withdrawn', icon: Icons.undo, kind: EcToneKind.danger),
        ConsentStatus.superseded => const ConsentBadge(label: 'Replaced', icon: Icons.history),
        _ => const ConsentBadge(label: 'Waiting for signature', icon: Icons.draw_outlined, kind: EcToneKind.warning),
      };
}

/// ML-DSA-65 seal check of a signed form. Colour is never the only signal (icon + text).
class ConsentSealChip extends StatelessWidget {
  const ConsentSealChip({super.key, required this.seal});
  final String? seal;

  @override
  Widget build(BuildContext context) => switch (seal) {
        'VALID' => const ConsentBadge(
            label: 'Sealed · ML-DSA-65', icon: Icons.verified_user_outlined, kind: EcToneKind.success, tooltip: 'The signed record verifies against the server seal'),
        'TAMPERED' => const ConsentBadge(label: 'Seal broken: record changed', icon: Icons.gpp_bad_outlined, kind: EcToneKind.danger),
        'UNSIGNED' => const ConsentBadge(label: 'Not sealed', icon: Icons.shield_outlined, kind: EcToneKind.warning),
        'UNKNOWN_KEY' => const ConsentBadge(label: 'Sealed with an unknown key', icon: Icons.key_off_outlined, kind: EcToneKind.warning),
        _ => const ConsentBadge(label: 'Seal not checked', icon: Icons.help_outline, kind: EcToneKind.warning),
      };
}

/// The form text in a readable, selectable, scrollable card.
class ConsentTextCard extends StatelessWidget {
  const ConsentTextCard({super.key, required this.body, this.maxHeight});
  final String body;

  /// When set, the card scrolls inside this height (dialogs); otherwise it grows with the page.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = SelectableText(body, key: const Key('consent-body'), style: theme.textTheme.bodyMedium?.copyWith(height: 1.5));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EcSpace.lg),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? EcColors.darkSurfaceAlt : EcColors.surfaceAlt,
        borderRadius: EcRadius.card,
        border: Border.all(color: theme.brightness == Brightness.dark ? EcColors.darkLine : EcColors.line),
      ),
      child: maxHeight == null
          ? text
          : ConstrainedBox(constraints: BoxConstraints(maxHeight: maxHeight!), child: Scrollbar(child: SingleChildScrollView(child: text))),
    );
  }
}

/// Staff: the full text of a form, its status and seal, read-only.
Future<void> showConsentTextDialog(BuildContext context, Consent c) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final muted = theme.colorScheme.onSurfaceVariant;
      return AlertDialog(
        title: Text('Consent form · ${c.subjectLabel ?? ''}'.trim()),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
                ConsentStatusChip(status: c.status),
                if (c.isSigned || c.seal != null) ConsentSealChip(seal: c.seal),
              ]),
              const SizedBox(height: EcSpace.sm),
              Text('${c.insurerName ?? 'Insurer'} · wording version ${c.templateVersion == 0 ? '0 (EasyClaim starter)' : c.templateVersion} · sent ${formatConsentDate(c.requestedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              if (c.isSigned) Text('Signed by ${c.signedName ?? '—'} on ${formatConsentDate(c.signedAt)}', style: theme.textTheme.bodySmall),
              if (c.isRefused && c.reason != null) Text('Customer\'s reason: ${c.reason}', style: theme.textTheme.bodySmall),
              const SizedBox(height: EcSpace.md),
              ConsentTextCard(body: c.body ?? 'The form text is not available.', maxHeight: 380),
              if (c.fingerprint != null) ...[
                const SizedBox(height: EcSpace.sm),
                SelectableText('Text fingerprint (SHA-256) ${c.fingerprint}…', style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: muted)),
              ],
            ]),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
    },
  );
}

/// Asks for confirmation with an optional reason (2–500 characters when given).
/// Returns null when cancelled, '' when confirmed without a reason.
Future<String?> showOptionalReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  bool destructive = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        final t = controller.text.trim();
        final ok = t.isEmpty || t.length >= 2;
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(message),
                const SizedBox(height: EcSpace.lg),
                TextField(
                  key: const Key('consent-reason'),
                  controller: controller,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Reason (optional)', helperText: 'Your insurer sees this.'),
                  onChanged: (_) => setState(() {}),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              key: confirmKey,
              style: destructive ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error) : null,
              onPressed: ok ? () => Navigator.pop(context, t) : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// Home: one attention card per consent form waiting for the customer's signature. Quiet (empty)
/// when there is nothing to sign or the list cannot be loaded; the rest of Home still works.
class PendingConsentBanner extends StatefulWidget {
  const PendingConsentBanner({super.key, this.repository, this.onChanged});
  final ConsentRepository? repository;
  final VoidCallback? onChanged;

  @override
  State<PendingConsentBanner> createState() => _PendingConsentBannerState();
}

class _PendingConsentBannerState extends State<PendingConsentBanner> with LiveRefresh {
  late final ConsentRepository _repo = widget.repository ?? ConsentRepository();
  List<Consent> _pending = const [];

  // Live: a form sent, signed, declined or withdrawn (on any device).
  @override
  bool wantsLive(RealtimeEvent e) => e.isConsent;

  @override
  void onLive() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _repo.mine();
      if (mounted) setState(() => _pending = all.where((c) => c.isPending).toList());
    } catch (_) {
      if (mounted) setState(() => _pending = const []);
    }
  }

  Future<void> _open(Consent c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsentFormScreen(consentId: c.id, repository: _repo)));
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final c in _pending)
        Padding(
          padding: const EdgeInsets.only(top: EcSpace.sm),
          child: EcTapTarget(
            key: Key('pending-consent-${c.id}'),
            onTap: () => _open(c),
            label: 'Consent form to sign from ${c.insurerName ?? 'your insurer'}, for ${consentSubjectText(c)}. Open to read and sign',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EcColors.brandText.withValues(alpha: 0.08),
                borderRadius: EcRadius.card,
                border: Border.all(color: EcColors.brandText.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.draw_outlined, color: EcColors.brandText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Consent form to sign — ${c.insurerName ?? 'your insurer'}',
                        style: const TextStyle(color: EcColors.brandText, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Needed before your insurer continues with ${consentSubjectText(c)}.',
                        style: const TextStyle(color: EcColors.ink, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: EcColors.brandText),
              ]),
            ),
          ),
        ),
    ]);
  }
}
