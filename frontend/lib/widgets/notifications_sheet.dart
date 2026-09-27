import 'package:flutter/material.dart';
import '../core/theme/ec_tokens.dart';
import 'neumorphic_button.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';

/// Claim updates for the signed-in customer, derived from their real claims (GET /claims).
/// There is no notifications API yet; this shows each claim's current stage and next step.
class NotificationsSheet extends StatelessWidget {
  final List<ClaimSummary> claims;
  final VoidCallback? onViewStagesTapped;

  const NotificationsSheet({super.key, required this.claims, this.onViewStagesTapped});

  static bool needsAction(ClaimSummary c) =>
      c.stage == BackendStage.infoNeeded || c.stage == BackendStage.draft || (c.stage == BackendStage.decision && c.status == 'Rejected');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
      color: Colors.white,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const Text('Claim updates',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 22.0, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2.0),
          const Text('Where each of your claims is right now',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
          const SizedBox(height: 16.0),
          if (claims.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No claims yet.', style: TextStyle(color: Color(0xFF64748B))),
            ),
          for (final c in claims)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: needsAction(c) ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: needsAction(c) ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(needsAction(c) ? Icons.error_outline_rounded : Icons.timeline_rounded,
                    color: needsAction(c) ? const Color(0xFFFF5500) : const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(presentStage(c.stage, status: c.status).label,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(nextStepFor(c.stage, status: c.status), style: const TextStyle(color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    Text('${c.category ?? 'Claim'} · ${c.id}',
                        style: const TextStyle(color: EcColors.inkMuted, fontSize: 11.5)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 8.0),
          NeumorphicButton(
            height: 50.0,
            variant: NeumorphicButtonVariant.primaryOrange,
            text: 'View claim stages',
            icon: Icons.timeline_rounded,
            onTap: () {
              Navigator.maybePop(context);
              onViewStagesTapped?.call();
            },
          ),
        ],
      ),
    );
  }
}
