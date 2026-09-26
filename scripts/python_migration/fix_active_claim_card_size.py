import re

with open('lib/widgets/active_claim_card.dart', 'r') as f:
    content = f.read()

# Make Logo smaller
content = content.replace("size: 54.0,", "size: 42.0,")
content = content.replace("borderRadius: 16.0,", "borderRadius: 8.0,")
content = content.replace("padding: 8.0,", "padding: 4.0,")

# Make text smaller
content = content.replace("fontSize: 18.5,", "fontSize: 16.0,")
content = content.replace("fontSize: 22.0,", "fontSize: 18.0,")
content = content.replace("fontSize: 14.5,", "fontSize: 13.0,")

# Reduce Stepper nodeSize? In claim_stepper.dart, it's 22.0, but I don't need to change stepper if I just reduce main padding.
content = content.replace("padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0)", "padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0)")
content = content.replace("const SizedBox(height: 16.0)", "const SizedBox(height: 10.0)")

with open('lib/widgets/active_claim_card.dart', 'w') as f:
    f.write(content)
