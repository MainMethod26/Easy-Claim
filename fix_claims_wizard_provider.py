import re

with open('frontend/lib/providers/claims_wizard_provider.dart', 'r') as f:
    content = f.read()

# Replace hardcoded policyId with selectedCampaignId
content = content.replace("'policyId': 'pol_123',", "'policyId': _wizardState.selectedCampaignId ?? 'pol_123',")

with open('frontend/lib/providers/claims_wizard_provider.dart', 'w') as f:
    f.write(content)
