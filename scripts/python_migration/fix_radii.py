import os

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    content = content.replace("BorderRadius.circular(28)", "BorderRadius.circular(8)")
    content = content.replace("BorderRadius.circular(28.0)", "BorderRadius.circular(8.0)")
    content = content.replace("BorderRadius.circular(24)", "BorderRadius.circular(8)")
    content = content.replace("BorderRadius.circular(24.0)", "BorderRadius.circular(8.0)")
    content = content.replace("BorderRadius.circular(20)", "BorderRadius.circular(8)")
    content = content.replace("BorderRadius.circular(20.0)", "BorderRadius.circular(8.0)")
    content = content.replace("BorderRadius.circular(18)", "BorderRadius.circular(4)")
    content = content.replace("BorderRadius.circular(18.0)", "BorderRadius.circular(4.0)")
    content = content.replace("BorderRadius.circular(16)", "BorderRadius.circular(4)")
    content = content.replace("BorderRadius.circular(16.0)", "BorderRadius.circular(4.0)")
    content = content.replace("BorderRadius.circular(14)", "BorderRadius.circular(4)")
    content = content.replace("BorderRadius.circular(14.0)", "BorderRadius.circular(4.0)")
    content = content.replace("BorderRadius.circular(12)", "BorderRadius.circular(4)")
    content = content.replace("BorderRadius.circular(12.0)", "BorderRadius.circular(4.0)")

    content = content.replace("Radius.circular(28)", "Radius.circular(8)")
    content = content.replace("Radius.circular(28.0)", "Radius.circular(8.0)")
    
    # Square up info tabs: mostly visited services are usually height ~ 85. Let's make them rectangular by adjusting width/height if specified.
    
    with open(filepath, 'w') as f:
        f.write(content)

fix_file('lib/screens/easy_claim_home_screen.dart')
fix_file('lib/screens/main_navigation_screen.dart')
fix_file('lib/screens/covers_screen.dart')
fix_file('lib/screens/support_screen.dart')

