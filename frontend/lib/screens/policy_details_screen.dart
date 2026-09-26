import 'package:flutter/material.dart';
import '../models/covers_models.dart';
import '../widgets/claims_wizard_modal.dart';
import '../providers/claims_wizard_provider.dart';
import 'package:provider/provider.dart';

class PolicyDetailsScreen extends StatelessWidget {
  final ActivePolicy policy;

  const PolicyDetailsScreen({Key? key, required this.policy}) : super(key: key);

  void _startClaimFlow(BuildContext context) {
    String categoryId = 'health_medical';
    if (policy.plan.category.name.toLowerCase().contains('vehicle')) {
      categoryId = 'vehicle_transit';
    } else if (policy.plan.category.name.toLowerCase().contains('home')) {
      categoryId = 'home_property';
    } else if (policy.plan.category.name.toLowerCase().contains('health')) {
      categoryId = 'health_medical';
    } else {
      categoryId = 'device_electronics';
    }

    ClaimsWizardModal.show(
      context,
      campaignName: policy.plan.name,
      campaignId: policy.policyNumber,
      initialCategory: categoryId,
      initialCoveredItemId: policy.assetName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          policy.plan.name,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(policy.plan.category.icon, size: 40, color: const Color(0xFF0F172A)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy.assetName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Policy #${policy.policyNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Manage Policy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildOptionCard(
                    icon: Icons.assignment_late_rounded,
                    title: 'Submit Claim',
                    subtitle: 'File a new claim',
                    color: const Color(0xFFFF5500),
                    onTap: () => _startClaimFlow(context),
                  ),
                  _buildOptionCard(
                    icon: Icons.description_rounded,
                    title: 'Documents',
                    subtitle: 'View policy docs',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Documents feature coming soon!')),
                      );
                    },
                  ),
                  _buildOptionCard(
                    icon: Icons.edit_document,
                    title: 'Update Details',
                    subtitle: 'Edit asset info',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Update Details feature coming soon!')),
                      );
                    },
                  ),
                  _buildOptionCard(
                    icon: Icons.cancel_presentation_rounded,
                    title: 'Cancel Policy',
                    subtitle: 'Terminate coverage',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cancel Policy feature coming soon!')),
                      );
                    },
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
