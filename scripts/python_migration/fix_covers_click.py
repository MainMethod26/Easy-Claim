import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

# Replace _openPolicyDetails implementation
old_open_policy = """  void _openPolicyDetails(ActivePolicy policy) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PolicyDetailsScreen(policy: policy)));
    return;
  }"""

new_open_policy = """  void _openPolicyDetails(ActivePolicy policy) {
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
      onCompleted: () {
        if (widget.onNavigateToActivities != null) {
          widget.onNavigateToActivities!();
        }
      },
    );
  }"""

content = content.replace(old_open_policy, new_open_policy)

# If the old method didn't match exactly because of my previous edits:
content = re.sub(r"void _openPolicyDetails\(ActivePolicy policy\) \{[\s\S]*?\}", new_open_policy, content)

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)
