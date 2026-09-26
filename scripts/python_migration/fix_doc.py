import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

pattern = r"showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.white,\s*shape: const RoundedRectangleBorder\(\s*borderRadius: BorderRadius\.vertical\(top: Radius\.circular\(24\)\),\s*\),\s*builder: \(sheetContext\) => (SafeArea\()"

repl = r"""Navigator.push(
      context,
      MaterialPageRoute(
        builder: (sheetContext) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: \1"""

content = re.sub(pattern, repl, content)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
