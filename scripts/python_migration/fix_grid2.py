with open('lib/screens/easy_claim_home_screen.dart', 'r') as f:
    content = f.read()

# Replace the crossAxisCount and childAspectRatio
content = content.replace("crossAxisCount: 3,", "crossAxisCount: 2,")
content = content.replace("childAspectRatio: 0.95,", "childAspectRatio: 2.8,")
content = content.replace("childAspectRatio: 0.95", "childAspectRatio: 2.8")

# I'll also modify the item builder using regex loosely
import re
old_item = r"""            child: Column\(
              mainAxisAlignment: MainAxisAlignment\.center,
              children: \[
                Container\(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration\(
                    color: const Color\(0xFFFF5500\)\.withValues\(alpha: 0\.12\),
                    borderRadius: BorderRadius\.circular\(10\),
                  \),
                  child: Icon\(
                    _getServiceIcon\(service\.icon\),
                    color: const Color\(0xFFFF5500\),
                    size: 20,
                  \),
                \),
                const SizedBox\(height: 8\),
                Text\(
                  service\.name,
                  style: const TextStyle\(
                    color: Color\(0xFF0F172A\),
                    fontSize: 12,
                    fontWeight: FontWeight\.w700,
                  \),
                  textAlign: TextAlign\.center,
                  maxLines: 1,
                  overflow: TextOverflow\.ellipsis,
                \),
                const SizedBox\(height: 2\),
                Text\(
                  '\$\{service\.visits\} visits',
                  style: const TextStyle\(color: Color\(0xFF64748B\), fontSize: 10\.5\),
                  textAlign: TextAlign\.center,
                \),
              \],
            \),"""

new_item = """            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _getServiceIcon(service.icon),
                    color: const Color(0xFFFF5500),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${service.visits} visits',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),"""

content = re.sub(old_item, new_item, content, flags=re.DOTALL)
with open('lib/screens/easy_claim_home_screen.dart', 'w') as f:
    f.write(content)
