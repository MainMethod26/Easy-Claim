import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Hide Subcategory chips if initialCategory is passed
old_subcat = """        // Subcategory Chips
        Text(
          'Specific ${selected.name} Type',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selected.subCategories.map((sub) {"""

new_subcat = """        // Subcategory Chips
        if (widget.initialCategory == null) ...[
          Text(
            'Specific ${selected.name} Type',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selected.subCategories.map((sub) {"""

content = content.replace(old_subcat, new_subcat)

old_subcat_end = """          }).toList(),
        ),

        const SizedBox(height: 18),"""

new_subcat_end = """          }).toList(),
          ),
          const SizedBox(height: 18),
        ],"""

content = content.replace(old_subcat_end, new_subcat_end)

# In _buildPolicyAndCoveredItemsSection, filter the coveredItems
old_covered_items = """  Widget _buildPolicyAndCoveredItemsSection(ClaimCategory selected) {
    final coveredItems = CoversMockData.getCoveredItemsByCategory(selected.categoryId);"""

new_covered_items = """  Widget _buildPolicyAndCoveredItemsSection(ClaimCategory selected) {
    var coveredItems = CoversMockData.getCoveredItemsByCategory(selected.categoryId);
    if (widget.initialCoveredItemId != null) {
      coveredItems = coveredItems.where((item) => item.assetName == widget.initialCoveredItemId).toList();
    }"""
content = content.replace(old_covered_items, new_covered_items)

# Make the subtitle not say "Select which device to claim" if prefilled
old_ins_sub_device = "insuranceSub = 'Vodacom Insurance Co. (Active Policy) • Select which device to claim';"
new_ins_sub_device = "insuranceSub = 'Vodacom Insurance Co. (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which device to claim' : '');"
content = content.replace(old_ins_sub_device, new_ins_sub_device)

old_ins_sub_veh = "insuranceSub = 'King Price Assurance (Active Policy) • Select which vehicle to claim';"
new_ins_sub_veh = "insuranceSub = 'King Price Assurance (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which vehicle to claim' : '');"
content = content.replace(old_ins_sub_veh, new_ins_sub_veh)

old_ins_sub_home = "insuranceSub = 'Discovery Insure (Active Policy) • Select which property to claim';"
new_ins_sub_home = "insuranceSub = 'Discovery Insure (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which property to claim' : '');"
content = content.replace(old_ins_sub_home, new_ins_sub_home)

old_ins_sub_health = "insuranceSub = 'Discovery Health (Active Policy) • Select which member to claim';"
new_ins_sub_health = "insuranceSub = 'Discovery Health (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which member to claim' : '');"
content = content.replace(old_ins_sub_health, new_ins_sub_health)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)

