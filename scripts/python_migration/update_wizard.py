import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Make it skip to Step 3 (Screening Context) directly if pre-filled!
old_skip = """    // Skip the Category step if prefilled
    if (widget.initialCategory != null) {
      _provider.goToStep(WizardStep.verifiedStage);
    }"""
new_skip = """    // Skip the Category and Verification steps if prefilled (direct to data capture)
    if (widget.initialCategory != null) {
      _provider.goToStep(WizardStep.screeningContext);
    }"""
content = content.replace(old_skip, new_skip)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
