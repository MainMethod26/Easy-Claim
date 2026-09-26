import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Revert the skip
old_skip = """    // Skip the Category and Verification steps if prefilled (direct to data capture)
    if (widget.initialCategory != null) {
      _provider.goToStep(WizardStep.screeningContext);
    }"""
new_skip = """    // No skipping steps as requested by user. We just pre-fill.
"""
content = content.replace(old_skip, new_skip)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
