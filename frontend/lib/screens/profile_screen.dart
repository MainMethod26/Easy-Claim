import '../core/auth/session.dart';
import '../core/theme/ec_status_colors.dart';
import '../core/theme/ec_tokens.dart';
import 'auth_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/setup_checklist.dart';
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
  void _signOut() {
    Session.instance.signOut();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  String get _roleLine {
    final a = Session.instance.actor;
    if (a == null) return 'Not signed in';
    final who = a.username == null ? a.userRole.label : '@${a.username} · ${a.userRole.label}';
    return a.tenantId == null ? who : '$who · ${a.tenantId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcColors.surface,
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
                  color: EcColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Personal details, data consent & security controls',
                style: TextStyle(color: EcColors.inkMuted, fontSize: 13.5),
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
                  borderRadius: EcRadius.card,
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
                        child: Icon(Icons.person_rounded, color: EcColors.brand, size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  Session.instance.actor?.label ?? 'Not signed in',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _roleLine,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Account: details, EasyClaim ID, linked policies (replaces the sample consent dashboard).
              const SetupChecklist(alwaysShow: true),
              const SizedBox(height: 8),

              const SizedBox(height: 14),

              // Quick Entry 3: Support & Ombudsman
              _buildSectionHeader('SUPPORT & CLAIMS OMBUDSMAN'),
              _buildSettingsCard([
                _buildActionRow(
                  icon: Icons.headset_mic_rounded,
                  iconColor: EcColors.brand,
                  title: 'Help and messages',
                  subtitle: 'Message your insurer about a claim, complaints route',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SupportScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: EcColors.line, height: 1),
                _buildActionRow(
                  icon: Icons.gavel_rounded,
                  iconColor: EcColors.warning,
                  title: 'Short-Term Insurance Ombudsman',
                  subtitle: 'Independent statutory mediator contact details',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ombudsman for Short-Term Insurance: 0860 726 890 (see Help for more)'),
                        backgroundColor: EcColors.brand,
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 30),

              // Sign out button
              Center(
                child: TextButton.icon(
                  onPressed: _signOut,
                  icon: Icon(Icons.logout_rounded, color: EcStatusColors.light.danger.foreground),
                  label: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: EcStatusColors.light.danger.foreground,
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
          color: EcColors.brandText, // brand orange is below 4.5:1 on white at this size
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Material(
      color: EcColors.surface,
      borderRadius: EcRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: EcRadius.card,
          border: Border.all(color: EcColors.line),
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
          borderRadius: EcRadius.card,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: EcColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: EcStatusColors.light.success.background,
                borderRadius: BorderRadius.circular(EcRadius.sm),
                border: Border.all(color: EcStatusColors.light.success.foreground),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: EcStatusColors.light.success.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: EcColors.inkMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: EcColors.inkSubtle, size: 14),
    );
  }

}
