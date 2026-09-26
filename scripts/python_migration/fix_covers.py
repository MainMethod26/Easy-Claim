import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

# Remove the campaign variables and references from _buildAllCoversView
# (I already removed the ribbon rendering before)
content = re.sub(r"final campaigns = _provider.activeCampaigns;\n", "", content)

# Remove _buildCampaignCard completely
content = re.sub(r"Widget _buildCampaignCard\(Campaign campaign\) \{.*?\n  \}\n", "", content, flags=re.DOTALL)

# Remove the campaignBadge block
campaign_badge_block = r"if \(plan\.campaignBadge != null\)[\s\S]*?,\n\s*\),?\n\s*\),?\n"
# Actually let's use a simpler way
content = re.sub(r"if\s*\(plan\.campaignBadge\s*!=\s*null\)\s*Container\([\s\S]*?child:\s*Text\([\s\S]*?plan\.campaignBadge![\s\S]*?\},?\s*\n\s*\),?\n\s*\),?", "", content)
# It's better to just regex the exact text
content = re.sub(r"if \(plan\.campaignBadge != null\)[\s\S]*?\]\n\s*,\n\s*const SizedBox\(height: 2\),", "],\n                      const SizedBox(height: 2),", content)


# Make Border Radii sharper
content = content.replace("BorderRadius.circular(20)", "BorderRadius.circular(8)")
content = content.replace("BorderRadius.circular(28)", "BorderRadius.circular(8)")
content = content.replace("BorderRadius.circular(18)", "BorderRadius.circular(8)")
content = content.replace("BorderRadius.circular(16)", "BorderRadius.circular(8)")
content = content.replace("BorderRadius.circular(24)", "BorderRadius.circular(8)")
content = content.replace("Radius.circular(28)", "Radius.circular(8)")
content = content.replace("Radius.circular(24)", "Radius.circular(8)")

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)
