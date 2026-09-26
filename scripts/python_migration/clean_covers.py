import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

content = re.sub(r"void _openPlanDetails\(.*?\}\n  \}\n", "", content, flags=re.DOTALL)
content = re.sub(r"void _openJoinPlanModal\(.*?\}\n  \}\n", "", content, flags=re.DOTALL)
content = re.sub(r"PlanCategory\? _selectedFilterCategory;\n", "", content)
content = re.sub(r"Widget _buildFormInput\(.*?\}\n", "", content, flags=re.DOTALL)
content = re.sub(r"Widget _buildSheetDetailRow\(.*?\}\n", "", content, flags=re.DOTALL)

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)
