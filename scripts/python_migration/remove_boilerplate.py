import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Step 3
content = content.replace("""        const Text(
          'Capturing evidence up front eliminates avoidable claim rejections.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),""", "")

# Step 4
content = content.replace("""        const Text(
          'Upload relevant documents or photos via this guided checklist.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),""", "")

# Step 5
content = content.replace("""        const Text(
          'Displays a transparent summary before formal submission into the review queue.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),""", "")

# Step 6
content = content.replace("""        const Text(
          'Real-time tracking through the remainder of the lifecycle until payout.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),""", "")


with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)

