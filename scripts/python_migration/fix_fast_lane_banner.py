import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Remove the specific banner container
content = re.sub(
    r"Container\(\s*padding: const EdgeInsets.symmetric\(horizontal: 8, vertical: 3\),\s*decoration: BoxDecoration\(\s*color: const Color\(0xFFF0FDF4\),\s*borderRadius: BorderRadius.circular\(6\),\s*border: Border.all\(color: const Color\(0xFF16A34A\)\),\s*\),\s*child: const Text\(\s*'Fast Lane Eligible',\s*style: TextStyle\(\s*color: Color\(0xFF16A34A\),\s*fontSize: 11,\s*fontWeight: FontWeight.w800,\s*\),\s*\),\s*\),",
    "",
    content,
    flags=re.DOTALL
)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)

