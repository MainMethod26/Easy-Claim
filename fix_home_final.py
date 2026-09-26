import re

with open('frontend/lib/providers/home_screen_provider.dart', 'r') as f:
    content = f.read()

# Fix ClaimStatus
content = content.replace(
    "lastUpdated: DateTime.parse(c['lastUpdated']),",
    "lastUpdated: DateTime.parse(c['lastUpdated']),\n            policyNumber: 'pol_123',\n            category: PlanCategory.device,"
)

# Fix SummaryStage
content = re.sub(r"policyName: s\['policyName'\],\n\s*", "", content)

# Fix StageMilestone
content = content.replace(
    "title: m['title'],",
    "title: m['title'],\n              description: 'Completed step.',"
)

with open('frontend/lib/providers/home_screen_provider.dart', 'w') as f:
    f.write(content)

