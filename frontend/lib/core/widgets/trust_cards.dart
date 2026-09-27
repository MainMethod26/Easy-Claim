import 'package:flutter/material.dart';
import '../theme/ec_tokens.dart';

import '../../data/models/api_models.dart';

/// Insurer-facing screening card (advisory signal). Wording rules: a screening signal and an
/// anomaly indicator, never a fraud finding; a human always decides.
class ScreeningCard extends StatelessWidget {
  final RiskSignals? signals;
  const ScreeningCard({super.key, required this.signals});

  static String bandLabel(double score) {
    if (score >= 0.9) return 'High';
    if (score >= 0.6) return 'Elevated';
    return 'Normal';
  }

  static Color bandColor(String band) {
    switch (band) {
      case 'HIGH':
        return const Color(0xFFDC2626);
      case 'ELEVATED':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = signals;
    return _CardShell(
      title: 'Screening',
      child: s == null
          ? const Text('No screening signal for this claim.', style: TextStyle(color: Color(0xFF64748B)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row('Classical signal', '${bandLabel(s.classicalAnomaly)} (${s.classicalAnomaly.toStringAsFixed(2)})'),
              _row('Quantum signal', '${bandLabel(s.quantumAnomaly)} (${s.quantumAnomaly.toStringAsFixed(2)})'),
              const Divider(height: 20),
              Row(children: [
                const Text('Overall', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bandColor(s.anomalyBand).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s.anomalyBand,
                      style: TextStyle(color: bandColor(s.anomalyBand), fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              _row('Recommendation', s.reviewRequired ? 'REVIEW REQUIRED' : 'STANDARD REVIEW'),
              const SizedBox(height: 8),
              Text(s.explanation, style: const TextStyle(color: Color(0xFF334155), height: 1.35)),
              const SizedBox(height: 8),
              Text(
                s.anomalyBand == 'HIGH'
                    ? 'Advisory signal. Human decision required.'
                    : 'Advisory signal. A human makes the decision.',
                style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 12.5),
              ),
              Text('Model ${s.modelVersion} · ${s.execution}',
                  style: const TextStyle(color: EcColors.inkMuted, fontSize: 11.5)),
            ]),
    );
  }
}

/// Decision integrity (ML-DSA-65 verification by the backend). It detects that signed decision
/// data no longer matches its signature; it does not prevent changes to the database.
class DecisionIntegrityCard extends StatelessWidget {
  final DecisionIntegrity? integrity;

  /// Customers get plain wording without algorithm details.
  final bool technical;
  final VoidCallback? onVerify;
  const DecisionIntegrityCard({super.key, required this.integrity, this.technical = true, this.onVerify});

  @override
  Widget build(BuildContext context) {
    final i = integrity;
    Widget body;
    if (i == null) {
      body = const Text('Not checked yet.', style: TextStyle(color: Color(0xFF64748B)));
    } else if (!i.hasDecision) {
      body = const Text('No decision recorded yet.', style: TextStyle(color: Color(0xFF64748B)));
    } else if (i.isValid) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Text(technical ? 'Cryptographically verified' : 'Decision verified',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534))),
        ]),
        const SizedBox(height: 6),
        if (technical) ...[
          Text(i.alg ?? 'ML-DSA-65'),
          if (i.keyId != null) Text('Key: ${i.keyId}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        ] else
          const Text('The recorded decision matches its digital signature.',
              style: TextStyle(color: Color(0xFF475569))),
        Text('Verified: ${_fmt(i.checkedAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ]);
    } else if (i.isTampered) {
      body = const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text('Integrity verification failed', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
        ]),
        SizedBox(height: 6),
        Text('The stored decision no longer matches its signature.'),
      ]);
    } else {
      body = Row(children: [
        const Icon(Icons.help_outline_rounded, color: Color(0xFFD97706)),
        const SizedBox(width: 8),
        Expanded(child: Text(_otherStatus(i.status))),
      ]);
    }
    return _CardShell(
      title: 'Decision integrity',
      trailing: onVerify == null ? null : TextButton(onPressed: onVerify, child: const Text('Verify integrity')),
      child: body,
    );
  }

  static String _otherStatus(String status) {
    switch (status) {
      case 'UNSIGNED':
        return 'This decision was recorded without a signature.';
      case 'UNKNOWN_KEY':
        return 'Signed with a key this server does not recognise.';
      default:
        return 'Integrity could not be checked right now.';
    }
  }

  static String _fmt(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    return '${l.day} ${months[l.month - 1]} ${l.year} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Flexible on both sides: long values wrap on narrow phones and at large text sizes.
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flexible(child: Text(label, style: const TextStyle(color: Color(0xFF475569)))),
        const SizedBox(width: EcSpace.md),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );

class _CardShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _CardShell({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EcColors.surface,
          borderRadius: EcRadius.card,
          border: Border.all(color: EcColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12, color: EcColors.ink)),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}
