import 'package:flutter/material.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/ec_tap_target.dart';
import '../data/models/api_models.dart';
import '../widgets/claims_wizard_modal.dart';

/// One of the customer's real policies (GET /covers/my-covers) and what they can do with it.
class PolicyDetailsScreen extends StatelessWidget {
  final Policy policy;
  final VoidCallback? onClaimSubmitted;

  const PolicyDetailsScreen({super.key, required this.policy, this.onClaimSubmitted});

  void _startClaimFlow(BuildContext context) {
    ClaimsWizardModal.show(context, policy: policy, onCompleted: onClaimSubmitted);
  }

  void _notAvailable(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not available in the app yet.'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(policy.planName, style: const TextStyle(color: EcColors.ink, fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: EcColors.ink),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EcColors.surfaceAlt,
                borderRadius: EcRadius.card,
                border: Border.all(color: EcColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 40, color: EcColors.ink),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(policy.insurerName ?? 'Insurer',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: EcColors.ink)),
                        const SizedBox(height: 4),
                        Text('Policy ${policy.id} · ${policy.status}', style: const TextStyle(fontSize: 14, color: EcColors.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!policy.isActive) ...[
              const SizedBox(height: 12),
              const Text('Claims can only be made on an active policy.', style: TextStyle(color: Color(0xFFB45309))), // amber-700: AA on white
            ],
            const SizedBox(height: 32),
            const Text('Manage policy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: EcColors.ink)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildOptionCard(
                    icon: Icons.assignment_late_rounded,
                    title: 'Submit claim',
                    subtitle: policy.isActive ? 'File a new claim' : 'Policy not active',
                    color: EcColors.brand,
                    onTap: policy.isActive ? () => _startClaimFlow(context) : () => _notAvailable(context, 'Claiming on an inactive policy'),
                  ),
                  _buildOptionCard(
                    icon: Icons.description_rounded,
                    title: 'Documents',
                    subtitle: 'Not available yet',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _notAvailable(context, 'Policy documents'),
                  ),
                  _buildOptionCard(
                    icon: Icons.edit_document,
                    title: 'Update details',
                    subtitle: 'Not available yet',
                    color: const Color(0xFF10B981),
                    onTap: () => _notAvailable(context, 'Updating policy details'),
                  ),
                  _buildOptionCard(
                    icon: Icons.cancel_presentation_rounded,
                    title: 'Cancel policy',
                    subtitle: 'Not available yet',
                    color: const Color(0xFFEF4444),
                    onTap: () => _notAvailable(context, 'Cancelling a policy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return EcTapTarget(
      onTap: onTap,
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EcColors.surface,
          borderRadius: EcRadius.card,
          border: Border.all(color: EcColors.line),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: EcColors.ink)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: EcColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
