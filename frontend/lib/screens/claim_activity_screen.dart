import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:getwidget/getwidget.dart';
import '../widgets/aurora_background.dart';
import '../services/logo_dev_service.dart';

class ClaimActivityScreen extends StatefulWidget {
  const ClaimActivityScreen({super.key});

  @override
  State<ClaimActivityScreen> createState() => _ClaimActivityScreenState();
}

class _ClaimActivityScreenState extends State<ClaimActivityScreen> {
  int _selectedView = 0; // 0 = 6 Stages, 1 = SLA & Benchmarks
  final int _activeStage = 4; // Currently at Review (1-indexed: 4)
  bool _showInfoNeeded = false;
  int _selectedStageIndex = 3; // 0-indexed: Stage 4 (Review) selected by default
  bool _isDropdownOpen = true; // Dropdown open by default

  void _onStageTapped(int index) {
    setState(() {
      if (_selectedStageIndex == index) {
        _isDropdownOpen = !_isDropdownOpen;
      } else {
        _selectedStageIndex = index;
        _isDropdownOpen = true;
      }
    });
  }

  final List<Map<String, dynamic>> _stages = [
    {
      'number': 1,
      'name': 'Submitted',
      'owner': 'Customer',
      'thaboSees': "Let's get your claim started.",
      'details': 'Police case number: CAS 482/09/2026 recorded. Time and place confirmed.',
      'endsWhen': 'Checklist complete',
      'durationHours': 0.2,
      'completed': true,
    },
    {
      'number': 2,
      'name': 'Verified',
      'owner': 'System',
      'thaboSees': 'We know who you are. Your cover is active.',
      'details': 'Identity and policy (active, covered, waiting period passed) verified in parallel.',
      'endsWhen': 'Both confirmed',
      'durationHours': 0.1,
      'completed': true,
    },
    {
      'number': 3,
      'name': 'Screening',
      'owner': 'System',
      'thaboSees': 'Running security checks.',
      'details': 'IMEI blacklist check clean. Fraud risk score: 14 (low risk route chosen).',
      'endsWhen': 'Route chosen',
      'durationHours': 0.1,
      'completed': true,
    },
    {
      'number': 4,
      'name': 'Review',
      'owner': 'System',
      'thaboSees': 'Good news, quick approval.',
      'details': 'R4,200 under R5,000 threshold. Policy age: 210 days. Auto-approval in progress.',
      'endsWhen': 'Outcome recorded',
      'durationHours': 4.5,
      'completed': false,
      'inProgress': true,
    },
    {
      'number': 5,
      'name': 'Decision',
      'owner': 'System or assessor',
      'thaboSees': 'Approved.',
      'details': 'Outcome recorded and customer notified immediately via push & SMS.',
      'endsWhen': 'Customer notified',
      'durationHours': 0.5,
      'completed': false,
    },
    {
      'number': 6,
      'name': 'Paid',
      'owner': 'System',
      'thaboSees': 'Your payout is on its way. How did we do?',
      'details': 'Payout of R4,200 triggered to verified Standard Bank account.',
      'endsWhen': 'Payment confirmed',
      'durationHours': 2.0,
      'completed': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AuroraBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Standard Model',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 28.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    const Text(
                      '6-Stage Standard Workflow & SLA Benchmarks',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // Neumorphic Segmented Selector
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            offset: const Offset(2, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSegmentButton(
                              index: 0,
                              label: '6 Stages Flow',
                            ),
                          ),
                          Expanded(
                            child: _buildSegmentButton(
                              index: 1,
                              label: 'SLA & Analytics',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // View Contents
              Expanded(
                child: _selectedView == 0
                    ? _buildStagesTimelineView()
                    : _buildAnalyticsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
  }) {
    final isSelected = _selectedView == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedView = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5500) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.20),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF6E1800).withValues(alpha: 0.65),
                    offset: const Offset(2, 2),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13.0,
          ),
        ),
      ),
    );
  }

  // 1. Stages Timeline View using timelines_plus & getwidget
  Widget _buildStagesTimelineView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      children: [
        // Active Claim & Underwriter Header
        Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              BrandLogo(
                name: 'Apple',
                size: 40.0,
                borderRadius: 12.0,
                padding: 4.0,
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apple iPhone 14 Pro Max • POL-EC-98421',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.0),
                    Text(
                      'Underwritten by Vodacom Insurance Co.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.0),
              BrandLogo(
                name: 'Vodacom',
                size: 32.0,
                borderRadius: 8.0,
                padding: 3.0,
              ),
            ],
          ),
        ),



        // Side state: Info Needed alert
        if (_showInfoNeeded)
          Container(
            margin: const EdgeInsets.only(bottom: 14.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5500).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: const Color(0xFFFF5500)),
            ),
            child: Row(
              children: [
                const BrandLogo(
                  name: 'saps',
                  size: 26.0,
                  borderRadius: 6.0,
                  padding: 2.0,
                  fallbackIcon: Icons.info_outline,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Side state: Info Needed. Please upload SAPS docket slip.',
                    style: TextStyle(color: Color(0xFF7C2D00), fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showInfoNeeded = false),
                  child: const Text('Dismiss', style: TextStyle(color: Color(0xFFFF5500))),
                ),
              ],
            ),
          ),

        // Horizontal Stages Stepper
        _buildHorizontalStagesBar(),

        // Stage Dropdown Details Panel
        _buildStageDropdownDetails(),

        const SizedBox(height: 20.0),
      ],
    );
  }

  // Compact, Non-Scrollable Horizontal Stages Stepper Bar
  Widget _buildHorizontalStagesBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Dropdown Status
          Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 2.0, 4.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.timeline_rounded,
                        color: Color(0xFFFF5500),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '6-Stage Flow',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => setState(() => _isDropdownOpen = !_isDropdownOpen),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isDropdownOpen
                          ? const Color(0xFFFF5500).withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isDropdownOpen ? 'Collapse' : 'Details',
                          style: TextStyle(
                            color: _isDropdownOpen
                                ? const Color(0xFFFF5500)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _isDropdownOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _isDropdownOpen
                              ? const Color(0xFFFF5500)
                              : const Color(0xFF64748B),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Non-scrollable Row fitting all 6 stages across the width
          Row(
            children: List.generate(_stages.length, (index) {
              final stage = _stages[index];
              final isCurrent = stage['number'] == _activeStage;
              final isCompleted = stage['completed'] as bool;
              final isInProgress = stage['inProgress'] == true;
              final isSelected = _selectedStageIndex == index;

              final String shortName = switch (index) {
                0 => 'Submit',
                1 => 'Verify',
                2 => 'Screen',
                3 => 'Review',
                4 => 'Decide',
                _ => 'Payout',
              };

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onStageTapped(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Continuous Connecting Line + Node Row
                      SizedBox(
                        height: 28.0,
                        child: Row(
                          children: [
                            // Left connector
                            Expanded(
                              child: Container(
                                height: 2.0,
                                color: index > 0 && index <= _activeStage - 1
                                    ? const Color(0xFFFF5500)
                                    : (index == 0
                                        ? Colors.transparent
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),

                            // Circle Node (26px)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 26.0,
                              height: 26.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted || isInProgress
                                    ? const Color(0xFFFF5500)
                                    : const Color(0xFFF1F5F9),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFF5500)
                                      : (isCompleted || isInProgress
                                          ? Colors.transparent
                                          : const Color(0xFFCBD5E1)),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected || isInProgress
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF5500)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 15.0,
                                      )
                                    : (isInProgress
                                        ? const Icon(
                                            Icons.bolt_rounded,
                                            color: Colors.white,
                                            size: 15.0,
                                          )
                                        : Text(
                                            '${stage['number']}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10.5,
                                            ),
                                          )),
                              ),
                            ),

                            // Right connector
                            Expanded(
                              child: Container(
                                height: 2.0,
                                color: index < _activeStage - 1
                                    ? const Color(0xFFFF5500)
                                    : (index == _stages.length - 1
                                        ? Colors.transparent
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5.0),

                      // Stage Label
                      Text(
                        shortName,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFFF5500)
                              : (isCurrent
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B)),
                          fontWeight: isSelected || isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 10.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),

                      // Dropdown pointer caret
                      Icon(
                        isSelected && _isDropdownOpen
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 16.0,
                        color: isSelected && _isDropdownOpen
                            ? const Color(0xFFFF5500)
                            : (isSelected ? const Color(0xFFFF5500) : Colors.transparent),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Interactive Dropdown Details Panel
  Widget _buildStageDropdownDetails() {
    final stage = _stages[_selectedStageIndex];
    final isCompleted = stage['completed'] as bool;
    final isInProgress = stage['inProgress'] == true;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: _isDropdownOpen
          ? Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: const Color(0xFFFF5500).withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown Header Banner
                  Container(
                    padding: const EdgeInsets.fromLTRB(16.0, 14.0, 12.0, 14.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18.5)),
                    ),
                    child: Row(
                      children: [
                        // Stage Number Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5500),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'STAGE ${stage['number']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Stage Name
                        Expanded(
                          child: Text(
                            stage['name'] as String,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),

                        // Status Badge
                        GFBadge(
                          text: isCompleted
                              ? 'DONE'
                              : (isInProgress ? 'ACTIVE' : 'PENDING'),
                          color: isCompleted
                              ? const Color(0xFF0055FF)
                              : (isInProgress
                                  ? const Color(0xFFFF5500)
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),

                        // Collapse Button
                        InkWell(
                          onTap: () => setState(() => _isDropdownOpen = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stage Dropdown Selector Menu
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stage Breakdown Dropdown',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedStageIndex,
                              isDense: true,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFFFF5500),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                              items: _stages.asMap().entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Text('Stage ${entry.value['number']}: ${entry.value['name']}'),
                                );
                              }).toList(),
                              onChanged: (newIdx) {
                                if (newIdx != null) _onStageTapped(newIdx);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Color(0xFFF1F5F9), height: 22, thickness: 1),

                  // Body Content of the Dropdown
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "What User Sees" Quote Callout
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Color(0xFFFF5500),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Customer Notification (User sees):',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '"${stage['thaboSees']}"',
                                      style: const TextStyle(
                                        color: Color(0xFFFF5500),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Audit & Detailed Explanation
                        const Text(
                          'Stage Details & Audit Trail',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stage['details'] as String,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3 KPI Pills: Owner, SLA, Gate
                        Row(
                          children: [
                            Expanded(
                              child: _buildStageInfoPill(
                                label: 'Owner',
                                value: stage['owner'] as String,
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStageInfoPill(
                                label: 'Est. Duration',
                                value: '${stage['durationHours']} hrs',
                                icon: Icons.timer_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStageInfoPill(
                                label: 'Ends When',
                                value: stage['endsWhen'] as String,
                                icon: Icons.flag_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Navigation Buttons in Dropdown (Prev / Next / Close)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_selectedStageIndex > 0)
                              TextButton.icon(
                                onPressed: () => _onStageTapped(_selectedStageIndex - 1),
                                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                label: Text('Stage $_selectedStageIndex'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            if (_selectedStageIndex < _stages.length - 1)
                              ElevatedButton.icon(
                                onPressed: () => _onStageTapped(_selectedStageIndex + 1),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: Text('Stage ${_selectedStageIndex + 2}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5500),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _isDropdownOpen = false),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Close Dropdown'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0055FF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: () => setState(() => _isDropdownOpen = true),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Color(0xFFFF5500), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Stage ${stage['number']}: ${stage['name']} Details',
                          style: const TextStyle(
                            color: Color(0xFFFF5500),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'Open Dropdown',
                          style: TextStyle(
                            color: Color(0xFFFF5500),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFFF5500),
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStageInfoPill({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 2. SLA & Analytics View using fl_chart
  Widget _buildAnalyticsView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      children: [
        // Summary KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Avg End-to-End',
                value: '7.4 hrs',
                trend: '3x faster',
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Auto-Approval Rate',
                value: '74%',
                trend: 'Auto-approved',
                isPositive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // Bar Chart: Time Per Stage (Shows Bottleneck)
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Per Stage (Hours)',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 16.0,
                    ),
                  ),
                  Text(
                    'SLA Bottleneck Analysis',
                    style: TextStyle(
                      color: Color(0xFFFF5500),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              const Text(
                'Stage 4 (Review) accounts for the largest SLA allocation.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
              ),
              const SizedBox(height: 24.0),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 6.0,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const titles = ['Sub', 'Ver', 'Scr', 'Rev', 'Dec', 'Paid'];
                            final idx = value.toInt();
                            if (idx >= 0 && idx < titles.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  titles[idx],
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}h',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Color(0xFFE2E8F0),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeBarGroup(0, 0.2, const Color(0xFFFF5500)), // Orange
                      _makeBarGroup(1, 0.1, const Color(0xFFFF5500)), // Orange
                      _makeBarGroup(2, 0.1, const Color(0xFFFF5500)), // Orange
                      _makeBarGroup(3, 4.5, const Color(0xFF0055FF)), // Peak Royal Blue
                      _makeBarGroup(4, 0.5, const Color(0xFF3B82F6)), // Blue
                      _makeBarGroup(5, 2.0, const Color(0xFF0055FF)), // Royal Blue
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Pie Chart: Customer Time vs Insurer Time (Orange & Blue)
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Time vs Insurer Time',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 4.0),
              const Text(
                'Shows who is actually waiting on whom across all active claims.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFFFF5500),
                            value: 18,
                            title: '18%',
                            radius: 36,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFFF5500),
                            value: 82,
                            title: '82%',
                            radius: 36,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: Color(0xFFFF5500)),
                            SizedBox(width: 8),
                            Text(
                              'Insurer Processing: 82%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: Color(0xFFFF5500)),
                            SizedBox(width: 8),
                            Text(
                              'Customer Input: 18%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String trend,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 22.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            trend,
            style: TextStyle(
              color: isPositive ? const Color(0xFF0055FF) : const Color(0xFFFF5500),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
