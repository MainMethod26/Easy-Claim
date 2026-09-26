import re

with open('lib/screens/easy_claim_home_screen.dart', 'r') as f:
    content = f.read()

# Replace _showSapsAssistSheet
saps_pattern = r"void _showSapsAssistSheet\(\) \{\s*showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.transparent,\s*builder: \(context\) => (.*?)\s*\);\s*\}"

def saps_repl(match):
    body = match.group(1)
    # remove the closing parenthesis of showModalBottomSheet if it's there
    return f"""  void _showSapsAssistSheet() {{
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: {body},
        ),
      ),
    );
  }}"""

content = re.sub(saps_pattern, saps_repl, content, flags=re.DOTALL)

with open('lib/screens/easy_claim_home_screen.dart', 'w') as f:
    f.write(content)
