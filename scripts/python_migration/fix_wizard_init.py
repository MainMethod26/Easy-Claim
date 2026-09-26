import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

old_init = """    // Apply covered items corresponding to the active insurance category
    _applyCategoryCoveredItems(initialCat.categoryId, preferCoveredItemId: widget.initialCoveredItemId);

    // Initialize photo evidence for the category (limit: 5 photos)
    _initPhotosForCategory(initialCat.categoryId);
  }"""

new_init = """    // Apply covered items corresponding to the active insurance category
    _applyCategoryCoveredItems(initialCat.categoryId, preferCoveredItemId: widget.initialCoveredItemId);

    // Initialize photo evidence for the category (limit: 5 photos)
    _initPhotosForCategory(initialCat.categoryId);

    // Skip the Category step if prefilled
    if (widget.initialCategory != null) {
      _provider.goToStep(WizardStep.verifiedStage);
    }
  }"""

content = content.replace(old_init, new_init)

# Remove the dumb boilerplate text from Step 1 just in case it is seen
old_step_1 = """        const Text(
          'Selection options dynamically adapt the verification & filing checklist.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),"""
content = content.replace(old_step_1, "")

# And in Step 2: "System automatically checked..."
old_step_2_desc = """        const Text(
          'System automatically checked identity, policy standing, and wait periods.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),"""
new_step_2_desc = """        const Text(
          'Your active policy is verified and in good standing.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),"""
content = content.replace(old_step_2_desc, new_step_2_desc)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
