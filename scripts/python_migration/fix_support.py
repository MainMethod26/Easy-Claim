import re

with open('lib/screens/support_screen.dart', 'r') as f:
    content = f.read()

pattern = r"showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.transparent,\s*builder: \(context\) => (.*?)\s*\);"

def repl(match):
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

content = re.sub(pattern, repl, content, flags=re.DOTALL)

with open('lib/screens/support_screen.dart', 'w') as f:
    f.write(content)
