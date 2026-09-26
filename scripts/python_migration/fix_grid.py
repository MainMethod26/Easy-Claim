import re

with open('lib/screens/easy_claim_home_screen.dart', 'r') as f:
    content = f.read()

# Change mostly visited layout
old_grid = r"""  Widget _buildMostlyVisitedGrid\(List<MostlyVisitedService> services\) \{
    return GridView\.builder\(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics\(\),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount\(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0\.95,
      \),
      itemCount: services\.length,
      itemBuilder: \(context, index\) \{
        final service = services\[index\];
        return GestureDetector\(
          onTap: \(\) => _handleServiceShortcut\(service\),
          child: Container\(
            padding: const EdgeInsets\.all\(10\),
            decoration: BoxDecoration\(
              color: Colors\.white,
              borderRadius: BorderRadius\.circular\(4\),
              border: Border\.all\(color: const Color\(0xFFE2E8F0\)\),
              boxShadow: \[
                BoxShadow\(
                  color: Colors\.black\.withValues\(alpha: 0\.04\),
                  blurRadius: 8,
                  offset: const Offset\(0, 2\),
                \),
              \],
            \),
            child: Column\(
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
            \),
          \),
        \);
      \},
    \);
  \}"""

new_grid = """  Widget _buildMostlyVisitedGrid(List<MostlyVisitedService> services) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return GestureDetector(
          onTap: () => _handleServiceShortcut(service),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
            ),
          ),
        );
      },
    );
  }"""

content = re.sub(old_grid, new_grid, content, flags=re.DOTALL)
with open('lib/screens/easy_claim_home_screen.dart', 'w') as f:
    f.write(content)
