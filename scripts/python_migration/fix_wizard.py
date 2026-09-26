import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

# Fix static show method
pattern1 = r"return showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.transparent,\s*enableDrag: false,\s*builder: \(context\) => (ClaimsWizardModal\([^)]+\)),\s*\);"
def repl1(match):
    body = match.group(1)
    return f"""return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => {body},
      ),
    );"""
content = re.sub(pattern1, repl1, content, flags=re.DOTALL)

# Fix document upload modal
pattern2 = r"showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.white,\s*shape: const RoundedRectangleBorder\(\s*borderRadius: BorderRadius\.vertical\(top: Radius\.circular\(24\)\),\s*\),\s*builder: \(context\) => (Container\([^;]+\));"
def repl2(match):
    body = match.group(1)
    return f"""Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: {body},
        ),
      ),
    );"""
content = re.sub(pattern2, repl2, content, flags=re.DOTALL)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
