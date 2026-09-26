lines = []
with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.strip() == "void _applyCategoryCoveredItems(String categoryId, {String? preferCoveredItemId}) {":
        # The previous line is line i-1, empty. line i-2 is `  }`
        # Wait, let's just find `    );` before this.
        for j in range(i-1, -1, -1):
            if lines[j].strip() == ");":
                lines[j] = "        ),\n      ),\n    );\n"
                break
        break

for i, line in enumerate(lines):
    if line.strip() == "Widget _buildStepHeader(WizardStep step) {":
        for j in range(i-1, -1, -1):
            if lines[j].strip() == ");":
                lines[j] = "        ),\n      );\n"
                break
        break

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.writelines(lines)
