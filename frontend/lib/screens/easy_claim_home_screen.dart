import 'package:flutter/material.dart';
import '../core/auth/session.dart';
import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';
import '../data/repositories/repositories.dart';
import '../models/home_models.dart';
import '../providers/home_screen_provider.dart';
import '../widgets/easy_claim_logo.dart';
import '../widgets/status_bar_widget.dart';
import '../widgets/active_claim_card.dart';
import '../widgets/claim_action_buttons.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/picture_background.dart';
import '../widgets/claims_wizard_modal.dart';
import 'consent_dashboard_screen.dart';
import 'support_screen.dart';

/// HOME: the signed-in customer's claims, straight from the backend.
/// 1. Account header (name from the session)
/// 2. Status banner derived from the claims (action needed / in progress / none)
/// 3. Latest claim with the 6-stage progress bar and "what happens next"
/// 4. Other claims
/// 5. Shortcuts and the new-claim / talk-to-a-person buttons
class EasyClaimHomeScreen extends StatefulWidget {
  final bool showStatusBar;
  final VoidCallback? onTalkToPersonTapped;
  final VoidCallback? onViewStagesTapped;
  final VoidCallback? onNavigateToCovers;
  final VoidCallback? onNavigateToProfile;
  final ClaimsRepository? claimsRepository;

  const EasyClaimHomeScreen({
    super.key,
    this.showStatusBar = true,
    this.onTalkToPersonTapped,
    this.onViewStagesTapped,
    this.onNavigateToCovers,
    this.onNavigateToProfile,
    this.claimsRepository,
  });

  @override
  State<EasyClaimHomeScreen> createState() => _EasyClaimHomeScreenState();
}

class _EasyClaimHomeScreenState extends State<EasyClaimHomeScreen> {
  late final HomeScreenProvider _home = HomeScreenProvider(claims: widget.claimsRepository);

  @override
  void initState() {
    super.initState();
    _home.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _home.removeListener(_onProviderUpdate);
    _home.dispose();
    super.dispose();
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: NotificationsSheet(claims: _home.claims, onViewStagesTapped: widget.onViewStagesTapped),
        ),
      ),
    );
  }

  void _startNewClaim() {
    ClaimsWizardModal.show(
      context,
      onCompleted: () {
        _home.refresh();
        widget.onViewStagesTapped?.call();
      },
    );
  }

  void _talkToPerson() {
    if (widget.onTalkToPersonTapped != null) {
      widget.onTalkToPersonTapped!();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final showSimulatedStatus = widget.showStatusBar && topInset == 0;
    final actor = Session.instance.actor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: PictureBackground(
        imageOpacity: 0.36,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              if (showSimulatedStatus) const MobileStatusBar(time: '9:41', color: Color(0xFF0F172A)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _home.refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const EasyClaimLogo(size: 42.0),
                            Row(children: [
                              NotificationBellButton(unreadCount: _home.actionCount, onTap: _showNotifications),
                              const SizedBox(width: 12.0),
                              GestureDetector(
                                onTap: widget.onNavigateToProfile,
                                child: Container(
                                  width: 48.0,
                                  height: 48.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4.0),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: const Center(child: Icon(Icons.person, color: Color(0xFFFF5500), size: 30.0)),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 20.0),
                        const Text('WELCOME BACK',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.0, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        const SizedBox(height: 2.0),
                        Text(
                          (actor?.label ?? 'Customer').toUpperCase(),
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18.0, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 10.0),
                        _buildStatusBanner(),
                        const SizedBox(height: 22.0),
                        _buildSectionTitle('Claim status'),
                        const SizedBox(height: 10.0),
                        _buildClaimSection(),
                        const SizedBox(height: 22.0),
                        _buildSectionTitle('Shortcuts'),
                        const SizedBox(height: 10.0),
                        _buildShortcuts(),
                        const SizedBox(height: 24.0),
                        PrimaryClaimButton(onTap: _startNewClaim),
                        const SizedBox(height: 12.0),
                        SecondaryContactButton(onTap: _talkToPerson),
                        const SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_home.isLoading || _home.error != null) return const SizedBox.shrink();
    final String text;
    final Color color;
    final IconData icon;
    if (_home.actionCount > 0) {
      text = _home.actionCount == 1 ? 'One claim needs your attention.' : '${_home.actionCount} claims need your attention.';
      color = const Color(0xFFEA580C);
      icon = Icons.error_outline_rounded;
    } else if (_home.claims.any((c) => c.stage != BackendStage.paid)) {
      text = 'Your claims are in progress. No action needed from you right now.';
      color = const Color(0xFF2563EB);
      icon = Icons.hourglass_top_rounded;
    } else {
      text = 'No open claims.';
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13.0, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _buildClaimSection() {
    if (_home.isLoading && _home.claims.isEmpty) return const LoadingView(message: 'Loading your claims…');
    if (_home.error != null) return ErrorView(error: _home.error!, onRetry: _home.refresh);
    final primary = _home.primaryClaim;
    if (primary == null) {
      return EmptyView(
        message: 'No claims yet. Start one when something happens.',
        icon: Icons.assignment_outlined,
        actionLabel: 'Start a claim',
        onAction: _startNewClaim,
      );
    }
    final stage = presentStage(primary.stage, status: primary.status);
    final others = _home.claims.where((c) => c.id != primary.id).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: widget.onViewStagesTapped,
        child: ActiveClaimCard(
          title: primary.title,
          claimant: Session.instance.actor?.label ?? 'You',
          amount: formatRand(primary.claimedAmountCents),
          status: stage.label,
          currentStep: stage.stage?.stepIndex ?? 0,
          logoName: primary.insurerName ?? 'EasyClaim',
        ),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFF5500), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(nextStepFor(primary.stage, status: primary.status),
                style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Other claims', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final c in others.take(4))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Expanded(
                child: Text('${c.category ?? 'Claim'} · ${formatRand(c.claimedAmountCents)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(presentStage(c.stage, status: c.status).label,
                  style: const TextStyle(color: Color(0xFFFF5500), fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
    ]);
  }

  Widget _buildShortcuts() {
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.add_circle_outline_rounded, 'New claim', _startNewClaim),
      (Icons.shield_outlined, 'My covers', widget.onNavigateToCovers),
      (Icons.timeline_rounded, 'Claim stages', widget.onViewStagesTapped),
      (Icons.privacy_tip_outlined, 'Consent', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsentDashboardScreen()))),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: [
        for (final (icon, label, onTap) in items)
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: const Color(0xFFFF5500)),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18.0, fontWeight: FontWeight.w800, letterSpacing: -0.2),
      );
}
