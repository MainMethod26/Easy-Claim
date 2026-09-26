import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Replace occurrences
content = content.replace("'Fast Lane'", "''")
content = content.replace("'Verified & Eligible For Fast Lane'", "'Verified & Eligible'")
content = content.replace("'Review & Fast Lane Submission'", "'Review Submission'")
content = content.replace("'4. Review (Fast Lane Active)'", "'4. Review'")

# The banner in Step 5: "Fast Lane Eligible"
# Let's find the block to remove.
content = re.sub(
    r"Container\(\s*padding: const EdgeInsets.symmetric\(horizontal: 8, vertical: 4\),\s*decoration: BoxDecoration\(\s*color: const Color\(0xFFF0FDF4\),\s*borderRadius: BorderRadius.circular\(6\),\s*\),\s*child: const Text\(\s*'Fast Lane Eligible',\s*style: TextStyle\(\s*color: Color\(0xFF16A34A\),\s*fontSize: 10,\s*fontWeight: FontWeight.w800,\s*\),\s*\),\s*\),",
    "",
    content,
    flags=re.DOTALL
)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
