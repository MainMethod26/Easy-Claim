import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'consent_dashboard_screen.dart';
import 'support_screen.dart';
import '../widgets/aurora_background.dart';

/// Profile Screen
/// Features:
/// - Account settings & personal details
/// - Consent Dashboard integration (underwriter, SAPS, fraud accessors)
/// - Security preferences (Biometrics, 2FA, Active sessions)
/// - Policy documents & support access
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricsEnabled = true;
  bool _smsAlertsEnabled = true;
  bool _twoFactorEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AuroraBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // Header
              const Text(
                'My Profile & Settings',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Personal details, data consent & security controls',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
              ),
              const SizedBox(height: 20),

              // User Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6600), Color(0xFFFF4000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Color(0xFFFF5500), size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AuthService.currentUserName ?? 'User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'ID: 940218 ··· 081 • Member since 2024',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          const Text(
                            'Verified Vault Identity',
                            style: TextStyle(color: Color(0xFFFFAB73), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Entry 1: Consent Dashboard
              _buildSectionHeader('DATA PRIVACY & VAULT'),
              _buildSettingsCard([
                _buildActionRow(
                  icon: Icons.lock_person_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Consent Dashboard',
                  subtitle: 'Manage 4 underwriters & SAPS API access permissions',
                  badge: '4 Active',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConsentDashboardScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                _buildActionRow(
                  icon: Icons.shield_moon_rounded,
                  iconColor: const Color(0xFF0284C7),
                  title: 'POPIA Compliance Audit',
                  subtitle: 'View cryptographic access records of your personal data',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('POPIA Certificate: All access logs cryptographically signed.'),
                        backgroundColor: Color(0xFF0284C7),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 22),

              // Quick Entry 2: Security Preferences
              _buildSectionHeader('SECURITY & AUTHENTICATION'),
              _buildSettingsCard([
                _buildSwitchRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Login (FaceID / TouchID)',
                  subtitle: 'Fast unlock using biometric security hardware',
                  value: _biometricsEnabled,
                  onChanged: (v) => setState(() => _biometricsEnabled = v),
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                _buildSwitchRow(
                  icon: Icons.security_rounded,
                  title: 'Two-Factor Authentication (2FA)',
                  subtitle: 'Require OTP verification for claim submissions',
                  value: _twoFactorEnabled,
                  onChanged: (v) => setState(() => _twoFactorEnabled = v),
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                _buildSwitchRow(
                  icon: Icons.sms_rounded,
                  title: 'Real-time Claim SMS Triggers',
                  subtitle: 'Receive instant notifications when claim stage moves',
                  value: _smsAlertsEnabled,
                  onChanged: (v) => setState(() => _smsAlertsEnabled = v),
                ),
              ]),

              const SizedBox(height: 22),

              // Quick Entry 3: Support & Ombudsman
              _buildSectionHeader('SUPPORT & CLAIMS OMBUDSMAN'),
              _buildSettingsCard([
                _buildActionRow(
                  icon: Icons.headset_mic_rounded,
                  iconColor: const Color(0xFFFF5500),
                  title: 'Claims Assistance & Agent Chat',
                  subtitle: 'Direct human access for disputes & queries',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SupportScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                _buildActionRow(
                  icon: Icons.gavel_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Short-Term Insurance Ombudsman',
                  subtitle: 'Independent statutory mediator contact details',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ombudsman for Short-Term Insurance: 0860 726 890'),
                        backgroundColor: Color(0xFFFF5500),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 30),

              // Sign out button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session locked securely.'),
                        backgroundColor: Color(0xFFFF5500),
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Lock Session & Sign Out',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFF6D00),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF16A34A)),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFF5500),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
