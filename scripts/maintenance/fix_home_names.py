import re

with open('frontend/lib/providers/home_screen_provider.dart', 'r') as f:
    content = f.read()

content = content.replace("ActiveClaimSummary(", "ClaimStatus(")
content = content.replace("ClaimSummaryStage(", "SummaryStage(")
content = content.replace("StageMilestone(", "StageMilestone(id: 'm_${DateTime.now().millisecondsSinceEpoch}', ")

with open('frontend/lib/providers/home_screen_provider.dart', 'w') as f:
    f.write(content)

