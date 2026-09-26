import 'dart:async';
import 'package:flutter/material.dart' hide Notification;
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
import '../services/logo_dev_service.dart';
import 'consent_dashboard_screen.dart';
import 'support_screen.dart';

/// HOME Screen — Client Layout & Detailed Architecture
/// Incorporates the exact handwritten client home structure:
/// 1. Welcome Banner: "Your cover is active. No pending actions required."
/// 2. Claim Status: Real-time visibility into active milestones (Submitted -> Paid).
/// 3. Summary Stage & Appeal: High-level overview with side states (Info Needed, Rejected, Appeal).
/// 4. Most Visited Services: Fast-access shortcuts with frequency tracking.
/// 5. Notifications: Alerts and triggers tracking who holds the clock.
/// 6. Recent Activity: Chronological log of recent policy updates and movements.
class EasyClaimHomeScreen extends StatefulWidget {
  final bool showStatusBar;
  final bool autoAdvanceStep;
  final VoidCallback? onTalkToPersonTapped;
  final VoidCallback? onViewStagesTapped;
  final VoidCallback? onNavigateToCovers;
  final VoidCallback? onNavigateToProfile;

  const EasyClaimHomeScreen({
    super.key,
    this.showStatusBar = true,
    this.autoAdvanceStep = true,
    this.onTalkToPersonTapped,
    this.onViewStagesTapped,
    this.onNavigateToCovers,
    this.onNavigateToProfile,
  });

  @override
  State<EasyClaimHomeScreen> createState() => _EasyClaimHomeScreenState();
}

class _EasyClaimHomeScreenState extends State<EasyClaimHomeScreen> {
  late HomeScreenProvider _homeProvider;
  Timer? _stepAutoTimer;

  @override
  void initState() {
    super.initState();
    _homeProvider = HomeScreenProvider();
    _homeProvider.addListener(_onProviderUpdate);
    if (widget.autoAdvanceStep) {
      _startStepAutoAdvance();
    }
  }

  void _startStepAutoAdvance() {
    _stepAutoTimer?.cancel();
    _stepAutoTimer =
        Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!mounted) return;
      final currentStep =
          _homeProvider.primaryClaim?.currentStage.stepIndex ?? 0;
      final nextStep = (currentStep + 1) % ClaimStage.values.length;
      _homeProvider.setClaimStage(ClaimStage.values[nextStep],
          recordActivity: false);
    });
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stepAutoTimer?.cancel();
    _homeProvider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsSheet(
        onViewStagesTapped: widget.onViewStagesTapped,
      ),
    ).then((_) {
      _homeProvider.markAllNotificationsRead();
    });
  }

  void _showNewClaimModal() {
    ClaimsWizardModal.show(
      context,
      onCompleted: () {
        if (widget.onViewStagesTapped != null) {
          widget.onViewStagesTapped!();
        }
      },
    );
  }

  void _showProfileModal() {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildProfileSheet(),
      );
    }
  }

  void _handleServiceShortcut(MostlyVisitedService service) {
    _homeProvider.recordServiceVisit(service.id);

    switch (service.id) {
      case 'srv_new_claim':
        _showNewClaimModal();
        break;
      case 'srv_my_covers':
        if (widget.onNavigateToCovers != null) {
          widget.onNavigateToCovers!();
        }
        break;
      case 'srv_stages':
        if (widget.onViewStagesTapped != null) {
          widget.onViewStagesTapped!();
        }
        break;
      case 'srv_consent':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConsentDashboardScreen()),
        );
        break;
      case 'srv_agent':
        if (widget.onTalkToPersonTapped != null) {
          widget.onTalkToPersonTapped!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SupportScreen()),
          );
        }
        break;
      case 'srv_saps':
        _showSapsAssistSheet();
        break;
      default:
        _showNewClaimModal();
        break;
    }
  }

  void _showSapsAssistSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 380,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SAPS Docket Synchronization',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Link or upload your South African Police Service incident report.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF16A34A)),
              ),
              child: const Row(
                children: [
                  BrandLogo(
                    name: 'saps',
                    size: 40,
                    borderRadius: 10,
                    padding: 4,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CAS 482/09/2026 Linked', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                        Text('Sandton SAPS Central Registry • Station Verified', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppealDialog() {
    final reasonController = TextEditingController(
      text: 'Police investigation confirmed robbery with weapon. Requesting ombudsman review under fast-lane exception policy.',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFFFF5500)),
            SizedBox(width: 10),
            Text(
              'File Formal Appeal',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'State your justification for submitting to the Senior Dispute Ombudsman:',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _homeProvider.submitAppeal(reasonController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appeal lodged with Senior Dispute Ombudsman!'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Appeal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final showSimulatedStatus = widget.showStatusBar && topInset == 0;
    final primaryClaim = _homeProvider.primaryClaim;
    final summaryStage = _homeProvider.currentSummaryStage;
    final mostlyVisited = _homeProvider.mostlyVisited;
    final activities = _homeProvider.recentActivities;
    final notifications = _homeProvider.notifications;

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

              // Scrollable screen content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top App Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const EasyClaimLogo(size: 42.0),
                          Row(
                            children: [
                              NotificationBellButton(
                                unreadCount: _homeProvider.unreadNotificationCount,
                                onTap: _showNotificationsModal,
                              ),
                              const SizedBox(width: 12.0),
                              GestureDetector(
                                onTap: _showProfileModal,
                                child: Container(
                                  width: 48.0,
                                  height: 48.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person, color: Color(0xFFFF5500), size: 30.0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),

                      // User Greeting & Welcome Banner
                      Row(
                        children: [
                          Container(
                            width: 38.0,
                            height: 38.0,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF0E6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('👋', style: TextStyle(fontSize: 20.0)),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          const Expanded(
                            child: Text(
                              'Welcome back, Thabo',
                              style: TextStyle(
                                color: Color(0xFFFF6D00),
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),

                      // Polished UX Copywriting: Welcome Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your cover is active. No pending actions required.',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22.0),

                      // Section Header: Claim Status & Summary Stage
                      _buildSectionTitle('Claim Status & Summary Stage'),
                      const SizedBox(height: 10.0),

                      // Active Claim Card with 6-step progress stepper (advances automatically)
                      ActiveClaimCard(
                        title: primaryClaim?.title ?? 'Phone stolen',
                        claimant: primaryClaim?.claimant ?? 'Thabo',
                        amount: primaryClaim?.amount ?? 'R4,200',
                        status: primaryClaim?.statusDisplay ?? 'Under review',
                        currentStep: primaryClaim?.currentStage.stepIndex ?? 3,
                      ),
                      const SizedBox(height: 14.0),

                      // Summary Stage & Appeal Card (Handwritten Layout)
                      if (summaryStage != null)
                        _buildSummaryStageAndAppealCard(summaryStage),

                      const SizedBox(height: 24.0),

                      // Section Header: Most Visited Services
                      _buildSectionTitle('Most Visited Services'),
                      const SizedBox(height: 10.0),

                      // Mostly Visited Grid
                      _buildMostlyVisitedGrid(mostlyVisited),

                      const SizedBox(height: 22.0),

                      // Notifications & Clock Tracking Card
                      _buildNotificationsClockCard(notifications),

                      const SizedBox(height: 22.0),

                      // Recent Activity Chronological Log
                      _buildRecentActivitySection(activities),

                      const SizedBox(height: 24.0),

                      // Action Button 1: Start a new claim (Neumorphic)
                      PrimaryClaimButton(
                        onTap: _showNewClaimModal,
                      ),
                      const SizedBox(height: 12.0),

                      // Action Button 2: Talk to a person (Neumorphic)
                      SecondaryContactButton(
                        onTap: () {
                          if (widget.onTalkToPersonTapped != null) {
                            widget.onTalkToPersonTapped!();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SupportScreen()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }

  // Summary Stage & Appeal Card
  Widget _buildSummaryStageAndAppealCard(SummaryStage stage) {
    final hasSideState = stage.sideState != null;
    final sideState = stage.sideState;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: hasSideState ? sideState!.color : const Color(0xFFE2E8F0),
          width: hasSideState ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Color(0xFFFF5500), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Summary Stage Overview',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasSideState
                      ? sideState!.color.withValues(alpha: 0.2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasSideState ? sideState!.color : const Color(0xFF16A34A),
                  ),
                ),
                child: Text(
                  stage.stageStatusText,
                  style: TextStyle(
                    color: hasSideState ? sideState!.color : const Color(0xFF16A34A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Milestone Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stage ${stage.currentStage.stepIndex + 1} of 6: ${stage.currentStage.displayName}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(stage.progressPercentage * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFFFF5500), fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stage.progressPercentage,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                hasSideState ? sideState!.color : const Color(0xFFFF5500),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            stage.stageDescription ?? 'Automated fast-lane processing active on claim EC-482.',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.35),
          ),

          // Side state specific banners
          if (sideState == ClaimSideState.infoNeeded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA726).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFA726)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: Color(0xFFFFA726), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Information Needed: Stamped SAPS affidavit requested.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _homeProvider.setSideState(null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Information submitted and verified!')),
                      );
                    },
                    child: const Text('Resolve', style: TextStyle(color: Color(0xFFFFAB73), fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ] else if (sideState == ClaimSideState.rejected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF5350)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Claim Rejected: Excess clause limitation cited.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _showAppealDialog,
                    child: const Text('Appeal', style: TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ] else if (sideState == ClaimSideState.appeal) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF42A5F5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFF42A5F5), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Appeal Active: Case under review by Senior Dispute Ombudsman.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),

          // Interactive Side State Simulator Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Simulate Side State:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildSideStateChip('Normal', null, sideState == null),
                  _buildSideStateChip('Info Needed', ClaimSideState.infoNeeded, sideState == ClaimSideState.infoNeeded),
                  _buildSideStateChip('Rejected', ClaimSideState.rejected, sideState == ClaimSideState.rejected),
                  _buildSideStateChip('Appeal', ClaimSideState.appeal, sideState == ClaimSideState.appeal),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideStateChip(String label, ClaimSideState? state, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (state == ClaimSideState.appeal && _homeProvider.currentSummaryStage?.sideState != ClaimSideState.appeal) {
          _showAppealDialog();
        } else {
          _homeProvider.setSideState(state);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5500) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Mostly Visited Grid
  Widget _buildMostlyVisitedGrid(List<MostlyVisitedService> services) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return GestureDetector(
          onTap: () => _handleServiceShortcut(service),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getServiceIcon(service.icon),
                    color: const Color(0xFFFF5500),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.name,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${service.visitCount} visits',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Notifications & Clock Tracking Card
  Widget _buildNotificationsClockCard(List<Notification> notifs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, color: Color(0xFFFF5500), size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Clock Tracking & Alerts',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF16A34A)),
                ),
                child: const Text(
                  'System Holds Clock',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Fast lane automated approval clock is running: Estimated decision under 4 hours.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),

          // First 2 notifications
          ...notifs.take(2).map((n) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: n.priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          n.message,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    n.timeAgo,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Recent Activity Section
  Widget _buildRecentActivitySection(List<RecentActivity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionTitle('Recent Activity')),
            if (widget.onViewStagesTapped != null)
              TextButton(
                onPressed: widget.onViewStagesTapped,
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: activities.take(3).map((act) {
              final brand = _getActivityBrand(act.title, act.description);
              return ListTile(
                leading: BrandLogo(
                  name: brand ?? 'apple',
                  size: 38,
                  borderRadius: 10,
                  fallbackIcon: _getActivityIcon(act.type),
                  fallbackIconColor: const Color(0xFFFF5500),
                ),
                title: Text(
                  act.title,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  act.description,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  act.timeAgo,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              );
            }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String? _getActivityBrand(String title, String description) {
    final text = '$title $description'.toLowerCase();
    if (text.contains('saps') || text.contains('police') || text.contains('cas')) {
      return 'saps';
    }
    if (text.contains('transunion') || text.contains('blacklist') || text.contains('imei')) {
      return 'transunion';
    }
    if (text.contains('capitec') || text.contains('premium') || text.contains('paid') || text.contains('r149')) {
      return 'capitec';
    }
    if (text.contains('vodacom') || text.contains('shield') || text.contains('policy')) {
      return 'vodacom';
    }
    if (text.contains('apple') || text.contains('iphone') || text.contains('ec-482')) {
      return 'apple';
    }
    return null;
  }

  Widget _buildProfileSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          const SizedBox(height: 20.0),
          const Text(
            'Thabo Bester',
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Text('ID: 940218 ··· 081', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 20.0),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Color(0xFFFF5500)),
            title: const Text('View Full Profile & Consent'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.pop(context);
              if (widget.onNavigateToProfile != null) {
                widget.onNavigateToProfile!();
              }
            },
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String iconKey) {
    switch (iconKey) {
      case 'flash':
        return Icons.flash_on_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'route':
        return Icons.alt_route_rounded;
      case 'lock':
        return Icons.lock_person_rounded;
      case 'headset':
        return Icons.headset_mic_rounded;
      case 'badge':
        return Icons.badge_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.claimSubmitted:
        return Icons.post_add_rounded;
      case ActivityType.claimStageUpdated:
        return Icons.update_rounded;
      case ActivityType.policyUpdated:
        return Icons.shield_rounded;
      case ActivityType.notification:
        return Icons.notifications_rounded;
      case ActivityType.payment:
        return Icons.payments_rounded;
      case ActivityType.documentUploaded:
        return Icons.description_rounded;
    }
  }
}
