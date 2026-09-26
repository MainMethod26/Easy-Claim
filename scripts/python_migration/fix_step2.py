import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

content = content.replace("""        const Text(
          'EasyClaim system verifies eligibility in real-time across underwriting databases.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),""", "")

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
