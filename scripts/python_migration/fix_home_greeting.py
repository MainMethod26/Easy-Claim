import re

with open('lib/screens/easy_claim_home_screen.dart', 'r') as f:
    content = f.read()

old_greeting = r"""                      // User Greeting & Welcome Banner
                      Row\(
                        children: \[
                          Container\(
                            width: 38\.0,
                            height: 38\.0,
                            decoration: const BoxDecoration\(
                              color: Color\(0xFFFFF0E6\),
                              shape: BoxShape\.circle,
                            \),
                            child: const Center\(
                              child: Text\('👋', style: TextStyle\(fontSize: 20\.0\)\),
                            \),
                          \),
                          const SizedBox\(width: 10\.0\),
                          const Expanded\(
                            child: Text\(
                              'Welcome back, Thabo',
                              style: TextStyle\(
                                color: Color\(0xFFFF6D00\),
                                fontSize: 17\.5,
                                fontWeight: FontWeight\.w800,
                                letterSpacing: -0\.2,
                              \),
                              overflow: TextOverflow\.ellipsis,
                            \),
                          \),
                        \],
                      \),"""

new_greeting = """                      // Proper Account Profile Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACCOUNT PROFILE',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                'THABO MOKOENA',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 1.0),
                              Text(
                                'ID: 9402185249081',
                                style: TextStyle(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 14),
                                SizedBox(width: 4),
                                Text('VERIFIED ID', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),"""

content = re.sub(old_greeting, new_greeting, content, flags=re.DOTALL)

with open('lib/screens/easy_claim_home_screen.dart', 'w') as f:
    f.write(content)
