import re

with open('lib/screens/policy_details_screen.dart', 'r') as f:
    content = f.read()

old_start_claim_flow = """  void _startClaimFlow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) {
          return ChangeNotifierProvider(
            create: (_) => ClaimsWizardProvider(),
            child: const ClaimsWizardModal(),
          );
        },
      ),
    );
  }"""

new_start_claim_flow = """  void _startClaimFlow(BuildContext context) {
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
      campaignId: policy.policyId,
      initialCategory: categoryId,
      initialCoveredItemId: policy.assetName,
    );
  }"""

content = re.sub(re.escape(old_start_claim_flow), new_start_claim_flow, content)

# Remove unused imports if there's any issue
with open('lib/screens/policy_details_screen.dart', 'w') as f:
    f.write(content)

