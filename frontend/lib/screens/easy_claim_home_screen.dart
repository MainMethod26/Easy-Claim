import 'package:flutter/material.dart';
import '../widgets/setup_checklist.dart';
import 'link_policy_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/auth/session.dart';
import '../core/realtime/live_refresh.dart';
import '../core/realtime/realtime_service.dart';
import '../core/widgets/live_indicator.dart';
import '../core/theme/ec_status_colors.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/ec_tap_target.dart';
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
import '../widgets/consent_widgets.dart';
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

class _EasyClaimHomeScreenState extends State<EasyClaimHomeScreen> with LiveRefresh {
  late final HomeScreenProvider _home = HomeScreenProvider(claims: widget.claimsRepository);

  /// Bumped on pull-to-refresh so the consent banner reloads too.
  int _consentGeneration = 0;

  Future<void> _refresh() async {
    setState(() => _consentGeneration++);
    await _home.refresh();
  }

  @override
  void initState() {
    super.initState();
    _home.addListener(_onProviderUpdate);
  }

  // Live: claim stages, messages and claim consent forms. The consent banner and the setup
  // checklist follow their own notices.
  @override
  bool wantsLive(RealtimeEvent e) => e.isClaimEvent;

  @override
  void onLive() => _home.refresh(quiet: true);

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
    // The decorative phone status bar is only drawn on a mobile layout, never on web or desktop.
    final showSimulatedStatus = widget.showStatusBar && topInset == 0 && !kIsWeb;
    final actor = Session.instance.actor;

    return Scaffold(
      backgroundColor: EcColors.surface,
      body: PictureBackground(
        imageOpacity: 0.36,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              if (showSimulatedStatus) const MobileStatusBar(time: '9:41', color: EcColors.ink),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
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
                              const LiveIndicator(),
                              const SizedBox(width: 8.0),
                              NotificationBellButton(unreadCount: _home.actionCount, onTap: _showNotifications),
                              const SizedBox(width: 12.0),
                              EcTapTarget(
                                onTap: widget.onNavigateToProfile,
                                label: 'Profile',
                                borderRadius: BorderRadius.circular(EcRadius.sm),
                                child: Container(
                                  width: 48.0,
                                  height: 48.0,
                                  decoration: BoxDecoration(
                                    color: EcColors.surface,
                                    borderRadius: BorderRadius.circular(EcRadius.sm),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: const Center(child: Icon(Icons.person, color: EcColors.brand, size: 30.0)),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 20.0),
                        const Text('WELCOME BACK',
                            style: TextStyle(color: EcColors.inkMuted, fontSize: 11.0, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        const SizedBox(height: 2.0),
                        Text(
                          (actor?.label ?? 'Customer').toUpperCase(),
                          style: const TextStyle(color: EcColors.ink, fontSize: 18.0, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 10.0),
                        _buildStatusBanner(),
                        // POPIA: consent forms waiting for the customer's signature.
                        PendingConsentBanner(key: ValueKey(_consentGeneration), onChanged: _home.refresh),
                        const SizedBox(height: 16.0),
                        const SetupChecklist(),
                        const SizedBox(height: 6.0),
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
      color = EcColors.brandText; // ≥ 4.5:1 on the light tint
      icon = Icons.error_outline_rounded;
    } else if (_home.claims.any((c) => c.stage != BackendStage.paid)) {
      text = 'Your claims are in progress. No action needed from you right now.';
      color = EcStatusColors.light.info.foreground;
      icon = Icons.hourglass_top_rounded;
    } else {
      text = 'No open claims.';
      color = EcStatusColors.light.success.foreground;
      icon = Icons.check_circle_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: EcRadius.card,
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
      _claimCard(
        ActiveClaimCard(
          title: primary.title,
          claimant: Session.instance.actor?.label ?? 'You',
          amount: formatRand(primary.claimedAmountCents),
          status: stage.label,
          currentStep: stage.stage?.stepIndex ?? 0,
          logoName: primary.insurerName ?? 'EasyClaim',
        ),
        'Latest claim: ${primary.title}, ${stage.label}. Open claim stages',
      ),
      if (MandateBadge.labelFor(primary.consent?.status, primary.consent?.viewedAt) != null) ...[
        const SizedBox(height: 8),
        MandateBadge(key: const Key('home-claim-mandate'), status: primary.consent?.status, viewedAt: primary.consent?.viewedAt, customer: true),
      ],
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EcColors.surfaceAlt,
          borderRadius: EcRadius.card,
          border: Border.all(color: EcColors.line),
        ),
        child: Row(children: [
          const Icon(Icons.arrow_forward_rounded, color: EcColors.brand, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(nextStepFor(primary.stage, status: primary.status),
                style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Other claims', style: TextStyle(color: EcColors.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final c in others.take(4))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: EcColors.surface,
              borderRadius: EcRadius.card,
              border: Border.all(color: EcColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${c.category ?? 'Claim'} · ${formatRand(c.claimedAmountCents)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(presentStage(c.stage, status: c.status).label,
                    style: const TextStyle(color: EcColors.brandText, fontWeight: FontWeight.w700)),
              ]),
              if (MandateBadge.labelFor(c.consentStatus, c.consentViewedAt) != null) ...[
                const SizedBox(height: 6),
                MandateBadge(status: c.consentStatus, viewedAt: c.consentViewedAt, customer: true),
              ],
            ]),
          ),
      ],
    ]);
  }

  /// The latest-claim card opens the claim stages when that destination exists.
  Widget _claimCard(Widget card, String label) {
    final onTap = widget.onViewStagesTapped;
    if (onTap == null) return card;
    return EcTapTarget(onTap: onTap, label: label, excludeChildSemantics: false, child: card);
  }

  Widget _buildShortcuts() {
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.add_circle_outline_rounded, 'New claim', _startNewClaim),
      (Icons.shield_outlined, 'My covers', widget.onNavigateToCovers),
      (Icons.timeline_rounded, 'Claim stages', widget.onViewStagesTapped),
      (Icons.link, 'Link policy', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkPolicyScreen()))),
    ];
    // A row of equal-height tiles (not a fixed aspect-ratio grid) so labels can wrap and the
    // tiles grow with larger text sizes instead of overflowing.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (icon, label, onTap)) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: EcTapTarget(
                onTap: onTap,
                label: label,
                child: Opacity(
                  opacity: onTap == null ? 0.5 : 1.0,
                  child: Container(
                  constraints: const BoxConstraints(minHeight: 84),
                  padding: const EdgeInsets.symmetric(horizontal: EcSpace.xs, vertical: EcSpace.sm),
                  decoration: BoxDecoration(
                    color: EcColors.surfaceSunken,
                    borderRadius: EcRadius.card,
                    border: Border.all(color: EcColors.line),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: EcColors.brand),
                    const SizedBox(height: 6),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: EcColors.ink)),
                  ]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(color: EcColors.ink, fontSize: 18.0, fontWeight: FontWeight.w800, letterSpacing: -0.2),
      );
}
