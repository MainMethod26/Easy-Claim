import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

content = re.sub(r"void _openCampaignClaimsFlow\(Campaign campaign\) \{.*?\n  \}\n", "", content, flags=re.DOTALL)
content = re.sub(r"Widget _buildPolicyDetailSheet\(ActivePolicy policy\) \{.*?\n  \}\n", "", content, flags=re.DOTALL)

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)
