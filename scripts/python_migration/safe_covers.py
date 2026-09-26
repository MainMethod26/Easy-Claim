import re

with open('lib/screens/covers_screen.dart', 'r') as f:
    content = f.read()

# Add InsurerProfileScreen import
content = content.replace("import '../widgets/aurora_background.dart';", "import '../widgets/aurora_background.dart';\nimport 'insurer_profile_screen.dart';")

# Replace _buildAllCoversView
old_all_covers_start = "  Widget _buildAllCoversView() {"
old_all_covers_end = "  Widget _buildCampaignCard(Campaign campaign) {"

if old_all_covers_start in content and old_all_covers_end in content:
    start_idx = content.find(old_all_covers_start)
    end_idx = content.find(old_all_covers_end)
    
    new_all_covers = """  Widget _buildAllCoversView() {
    final insurers = [
      {'name': 'Momentum', 'icon': Icons.shield_rounded, 'color': Color(0xFFE91E63)},
      {'name': 'King Price', 'icon': Icons.monetization_on_rounded, 'color': Color(0xFFD32F2F)},
      {'name': 'Clientèle Life', 'icon': Icons.health_and_safety_rounded, 'color': Color(0xFF1976D2)},
      {'name': 'Discovery', 'icon': Icons.explore_rounded, 'color': Color(0xFF388E3C)},
      {'name': 'Santam', 'icon': Icons.umbrella_rounded, 'color': Color(0xFFFBC02D)},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Integrated Network Insurers',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Select an insurer to view services, lodge a claim, or apply for new coverage.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: insurers.map((insurer) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InsurerProfileScreen(insurerName: insurer['name'] as String),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(insurer['icon'] as IconData, color: insurer['color'] as Color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insurer['name'] as String,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'View Profile & Plans',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

"""
    content = content[:start_idx] + new_all_covers + content[end_idx:]

# Let's fix the border radii since we restored from git
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

# Fix commas for Navigator.push since we checked out git
content = content.replace("),,", "),")

with open('lib/screens/covers_screen.dart', 'w') as f:
    f.write(content)

