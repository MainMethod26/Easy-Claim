import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

content = re.sub(r"Widget _buildCategoryFilterChip\(.*?\}\n", "", content, flags=re.DOTALL)
content = re.sub(r"Widget _buildMarketplacePlanCard\(.*?\}\n", "", content, flags=re.DOTALL)
content = re.sub(r"Widget _buildPlanDetailSheet\(.*?\}\n", "", content, flags=re.DOTALL)
content = re.sub(r"Widget _buildJoinPlanSheet\(.*?\}\n", "", content, flags=re.DOTALL)

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)
