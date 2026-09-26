import re

with open('lib/widgets/active_claim_card.dart', 'r') as f:
    content = f.read()

# Make corners sharper
content = content.replace("BorderRadius.circular(28.0)", "BorderRadius.circular(8.0)")

# Make it sleeker by reducing paddings and spacing
content = content.replace("padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0)", "padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0)")
content = content.replace("const SizedBox(height: 16.0)", "const SizedBox(height: 8.0)")
content = content.replace("const SizedBox(height: 28.0)", "const SizedBox(height: 14.0)")
content = content.replace("const SizedBox(height: 14.0)", "const SizedBox(height: 10.0)") # For the logo padding etc

# Let's target the exact SizedBoxes
# 1. After Active claim text:
content = content.replace("const SizedBox(height: 16.0),", "const SizedBox(height: 10.0),")
# 2. Before Stepper:
content = content.replace("const SizedBox(height: 28.0),", "const SizedBox(height: 16.0),")

with open('lib/widgets/active_claim_card.dart', 'w') as f:
    f.write(content)

