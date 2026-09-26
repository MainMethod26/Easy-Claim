with open('lib/screens/covers_screen.dart', 'r') as f:
    lines = f.readlines()

out_lines = []
skip = False
for line in lines:
    if "if (plan.campaignBadge != null)" in line:
        skip = True
        continue
    if skip and "]," in line:
        out_lines.append(line)
        skip = False
        continue
    if not skip:
        out_lines.append(line)

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.writelines(out_lines)
