import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

pattern = r"(Widget build\(BuildContext context\) \{[\s\S]*?)return Container\("
repl = r"\1return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))), body: Container("

content = re.sub(pattern, repl, content, count=1)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)
