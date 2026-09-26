import re

def fix_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    content = content.replace("campaignId: policy.policyId", "campaignId: policy.policyNumber")
    
    with open(file_path, 'w') as f:
        f.write(content)

fix_file('lib/screens/covers_screen.dart')
fix_file('lib/screens/policy_details_screen.dart')
