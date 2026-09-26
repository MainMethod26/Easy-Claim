import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:getwidget/getwidget.dart';
import '../services/logo_dev_service.dart';
import '../widgets/neumorphic_button.dart';

/// Support Agent representation
class SupportAgent {
  final String id;
  final String name;
  final String role;
  final String avatarUrl;
  final bool isOnline;
  final String averageWaitTime;
  final double rating;
  final String badge;
  final String phone;

  const SupportAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.isOnline = true,
    this.averageWaitTime = '< 2 mins',
    this.rating = 4.9,
    this.badge = 'Available Now',
    this.phone = '0800 242 468',
  });
}

/// Insurance Cover with available underwriter agents
class SupportCover {
  final String id;
  final String policyNumber;
  final String planName;
  final String underwriter;
  final String assetName;
  final String category;
  final String monthlyPremium;
  final List<SupportAgent> availableAgents;

  const SupportCover({
    required this.id,
    required this.policyNumber,
    required this.planName,
    required this.underwriter,
    required this.assetName,
    required this.category,
    required this.monthlyPremium,
    required this.availableAgents,
  });

  int get availableAgentsCount =>
      availableAgents.where((a) => a.isOnline).length;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Selected policy to view available agents (first one selected by default)
  String _selectedPolicyNumber = 'POL-EC-98421';
  String _selectedSlot = '10:30 AM (In 15m)';

  final List<String> _callSlots = [
    '10:30 AM (In 15m)',
    '11:45 AM',
    '02:15 PM',
    '04:00 PM',
  ];

  // Active Insurance Covers with their respective underwriter specialists
  final List<SupportCover> _covers = const [
    SupportCover(
      id: 'cov_device_pro',
      policyNumber: 'POL-EC-98421',
      planName: 'EasyShield Mobile Guard',
      underwriter: 'Vodacom Insurance Co.',
      assetName: 'Apple iPhone 14 Pro Max 256GB',
      category: 'Mobile & Device',
      monthlyPremium: 'R149 / mo',
      availableAgents: [
        SupportAgent(
          id: 'agent_sarah',
          name: 'Sarah Dlamini',
          role: 'Senior Device Claims Specialist',
          avatarUrl:
              'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 2 mins',
          rating: 4.9,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_kagiso',
          name: 'Kagiso Molefe',
          role: 'Fast-Lane Mobile Assessor',
          avatarUrl:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 3 mins',
          rating: 4.8,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_nadia',
          name: 'Nadia Pillay',
          role: 'Tier-2 Technical Evaluator',
          avatarUrl:
              'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 1 min',
          rating: 5.0,
          badge: 'Available Now',
        ),
        SupportAgent(
          id: 'agent_sipho',
          name: 'Sipho Sithole',
          role: 'SAPS Docket & Blacklist Officer',
          avatarUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 4 mins',
          rating: 4.7,
          badge: 'Online Now',
        ),
      ],
    ),
    SupportCover(
      id: 'cov_auto_commute',
      policyNumber: 'POL-EC-44102',
      planName: 'Transit & Roadside Secure',
      underwriter: 'King Price Assurance',
      assetName: 'Volkswagen Polo TSI (2022)',
      category: 'Vehicle & Roadside',
      monthlyPremium: 'R289 / mo',
      availableAgents: [
        SupportAgent(
          id: 'agent_johan',
          name: 'Johan van der Merwe',
          role: 'Lead Motor & Collision Assessor',
          avatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 2 mins',
          rating: 4.9,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_anathi',
          name: 'Anathi Mbeki',
          role: '24/7 Roadside Towing Dispatcher',
          avatarUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 1 min',
          rating: 5.0,
          badge: 'Instant Dispatch',
        ),
        SupportAgent(
          id: 'agent_lindiwe',
          name: 'Lindiwe Khumalo',
          role: 'Windscreen & OEM Parts Consultant',
          avatarUrl:
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 3 mins',
          rating: 4.8,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_bradley',
          name: 'Bradley Cooper',
          role: 'Accident Settlement Supervisor',
          avatarUrl:
              'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 2 mins',
          rating: 4.9,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_fatima',
          name: 'Fatima Patel',
          role: 'Vehicle Damage Inspector',
          avatarUrl:
              'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 3 mins',
          rating: 4.8,
          badge: 'Online Now',
        ),
      ],
    ),
    SupportCover(
      id: 'cov_home_shield',
      policyNumber: 'POL-EC-71829',
      planName: 'Home & Content All-Risk',
      underwriter: 'Discovery Insure',
      assetName: 'Sandton Residence & Contents',
      category: 'Property & Content',
      monthlyPremium: 'R410 / mo',
      availableAgents: [
        SupportAgent(
          id: 'agent_david',
          name: 'David Nkosi',
          role: 'Property & Building Claim Lead',
          avatarUrl:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 1 min',
          rating: 5.0,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_elena',
          name: 'Elena Rostova',
          role: 'Emergency Trades Dispatcher',
          avatarUrl:
              'https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 3 mins',
          rating: 4.8,
          badge: 'Online Now',
        ),
        SupportAgent(
          id: 'agent_tshepo',
          name: 'Tshepo Moeketsi',
          role: 'Structural Damage Evaluator',
          avatarUrl:
              'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200&fit=crop&q=80',
          isOnline: true,
          averageWaitTime: '< 2 mins',
          rating: 4.9,
          badge: 'Online Now',
        ),
      ],
    ),
  ];

  SupportCover get _currentSelectedCover {
    return _covers.firstWhere(
      (c) => c.policyNumber == _selectedPolicyNumber,
      orElse: () => _covers.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCover = _currentSelectedCover;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Talk to an Agent',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
          children: [
            // Guidance Banner
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.headset_mic_rounded,
                      color: Color(0xFF16A34A), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Underwriter Connection',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select one of your active covers below to see the exact number of certified agents available right now.',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12.0,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Section Header: My Covers
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YOUR ACTIVE COVERS',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Tap to select',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),

            // Insurance Cover Cards list
            ..._covers.map((cover) {
              final isSelected = cover.policyNumber == _selectedPolicyNumber;
              return _buildCoverCard(cover, isSelected);
            }),

            const SizedBox(height: 20.0),

            // Available Agents for the selected insurance cover
            _buildAvailableAgentsSection(selectedCover),

            const SizedBox(height: 24.0),

            // Emergency & Alternative Channels Section
            _buildEmergencyAndDirectChannels(context),
          ],
        ),
      ),
    );
  }

  /// Insurance Cover Card with Available Agents Count
  Widget _buildCoverCard(SupportCover cover, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPolicyNumber = cover.policyNumber;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Underwriter Logo, Names, and Active Badge
            Row(
              children: [
                BrandLogo(
                  name: cover.underwriter,
                  size: 42.0,
                  borderRadius: 12.0,
                  padding: 6.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cover.underwriter,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cover.planName,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A)),
                  ),
                  child: const Text(
                    'Active Cover',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Policy details row
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cover.assetName,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cover.policyNumber,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 10.0),

            // Bottom Bar: Highlighting the Number of Available Agents to Talk To
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Green live pulse indicator
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${cover.availableAgentsCount} Agents Available to Talk To',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF0F172A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSelected ? 'Viewing' : 'View',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFFF5500),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      color: isSelected
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFFF5500),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Available Agents Section for the chosen insurance cover
  Widget _buildAvailableAgentsSection(SupportCover cover) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Underwriter & Agent Count
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cover.availableAgentsCount} Available Agents for ${cover.underwriter}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Accredited assessors ready for instant claim discussion',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14.0),

          // Agents List
          ...cover.availableAgents.map((agent) {
            return _buildAgentTile(agent, cover);
          }),
        ],
      ),
    );
  }

  /// Individual Agent Tile with Avatar, Status, and Actions
  Widget _buildAgentTile(SupportAgent agent, SupportCover cover) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Online indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: CachedNetworkImage(
                      imageUrl: agent.avatarUrl,
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50.0,
                        height: 50.0,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.person, color: Color(0xFF94A3B8)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50.0,
                        height: 50.0,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.person, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: agent.isOnline
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12.0),

              // Agent info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agent.name,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15.0,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF16A34A), size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.role,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '★ ${agent.rating}',
                          style: const TextStyle(
                            color: Color(0xFFFF6D00),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  Wait: ${agent.averageWaitTime}',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Action Buttons: Chat & Call
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () => _openChatWithAgent(context, agent, cover),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Chat with Agent',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5500),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _callAgentDirect(context, agent, cover),
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      size: 16, color: Color(0xFF16A34A)),
                  label: const Text(
                    'Direct Call',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Emergency Hotline & WhatsApp channels
  Widget _buildEmergencyAndDirectChannels(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMERGENCY & ALTERNATIVE CHANNELS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10.0),

        // WhatsApp Assistant Card
        _buildSupportCard(
          context,
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF16A34A),
          title: 'WhatsApp Claims Assistant',
          subtitle:
              'Continue claim intake or upload photos/dockets via official verified bot.',
          badge: 'Fastest Reply',
          buttonText: 'Open WhatsApp',
          variant: NeumorphicButtonVariant.primaryOrange,
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.transparent,
                content: AwesomeSnackbarContent(
                  title: 'Connecting WhatsApp',
                  message: 'Opening EasyClaim WhatsApp verified bot...',
                  contentType: ContentType.help,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12.0),

        // Emergency Hotline Card
        _buildSupportCard(
          context,
          icon: Icons.phone_in_talk_rounded,
          iconColor: const Color(0xFF0055FF),
          title: 'Emergency Toll-Free Hotline',
          subtitle:
              'Immediate 24/7 telephonic claims dispatcher: 0800 242 468.',
          badge: '24/7 Available',
          buttonText: 'Call 0800 242 468',
          variant: NeumorphicButtonVariant.secondaryBlue,
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.transparent,
                content: AwesomeSnackbarContent(
                  title: 'Calling 0800 242 468',
                  message: 'Connecting to toll-free emergency claims line...',
                  contentType: ContentType.success,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12.0),

        // Schedule Call-Back Slot
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_callback_rounded,
                      color: Color(0xFFFF5500), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Request Free Call-Back',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  GFBadge(
                    text: 'Assessor SLA',
                    color: Color(0xFF0072FF),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              const Text(
                'Choose a convenient time today for an assessor to call you regarding your claim.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
              ),
              const SizedBox(height: 12.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _callSlots.map((slot) {
                  final isSel = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) setState(() => _selectedSlot = slot);
                    },
                    selectedColor: const Color(0xFFFF5500),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.0,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14.0),
              SizedBox(
                width: double.infinity,
                child: NeumorphicButton(
                  height: 48.0,
                  variant: NeumorphicButtonVariant.primaryOrange,
                  text: 'Confirm Call-Back Slot',
                  icon: Icons.calendar_today_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        elevation: 0,
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        content: AwesomeSnackbarContent(
                          title: 'Call-Back Booked',
                          message:
                              'An accredited underwriter specialist will call you at $_selectedSlot.',
                          contentType: ContentType.success,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required String buttonText,
    required NeumorphicButtonVariant variant,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Icon(icon, color: iconColor, size: 24.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16.0,
                  ),
                ),
              ),
              GFBadge(
                text: badge,
                color: const Color(0xFFF1F5F9),
                textColor: const Color(0xFF475569),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.0,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14.0),
          SizedBox(
            width: double.infinity,
            child: NeumorphicButton(
              height: 46.0,
              variant: variant,
              text: buttonText,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }

  /// Direct Call Action
  void _callAgentDirect(
      BuildContext context, SupportAgent agent, SupportCover cover) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 4),
        content: AwesomeSnackbarContent(
          title: 'Direct Call Initiated',
          message:
              'Connecting directly to ${agent.name} (${cover.underwriter}) via 0800 242 468...',
          contentType: ContentType.success,
        ),
      ),
    );
  }

  /// Live Interactive Chat Modal with the selected agent
  void _openChatWithAgent(
      BuildContext context, SupportAgent agent, SupportCover cover) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: _AgentChatModal(agent: agent, cover: cover),
        ),
      ),
    );
  }
}

/// Interactive Chat Modal for Direct Messaging
class _AgentChatModal extends StatefulWidget {
  final SupportAgent agent;
  final SupportCover cover;

  const _AgentChatModal({required this.agent, required this.cover});

  @override
  State<_AgentChatModal> createState() => _AgentChatModalState();
}

class _AgentChatModalState extends State<_AgentChatModal> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Seed initial greeting from the accredited underwriter agent
    _messages.add({
      'fromAgent': true,
      'text':
          'Hello User! I am ${widget.agent.name}, your claims assessor for ${widget.cover.underwriter}. I have your active policy (${widget.cover.policyNumber}) open for ${widget.cover.assetName}. How can I assist you right now?',
      'time': 'Just now',
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'fromAgent': false,
        'text': text,
        'time': 'Just now',
      });
      _isTyping = true;
    });

    if (quickText == null) {
      _msgCtrl.clear();
    }

    // Simulate realistic intelligent assessor response
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'fromAgent': true,
          'text': _generateAssessorResponse(text),
          'time': 'Just now',
        });
      });
    });
  }

  String _generateAssessorResponse(String userText) {
    final lower = userText.toLowerCase();
    if (lower.contains('status') || lower.contains('stage')) {
      return 'Your claim for ${widget.cover.assetName} is verified and currently progressing through our automated review. All criteria have passed!';
    } else if (lower.contains('payout') ||
        lower.contains('money') ||
        lower.contains('settlement')) {
      return 'Payout of R4,200 is pre-authorized. Once the final review checks finish today, payment will transfer straight to your linked account.';
    } else if (lower.contains('police') || lower.contains('docket')) {
      return 'We have already retrieved police CAS docket 482/09/2026 via our automated SAPS API gateway. No physical paperwork needed from you!';
    } else {
      return 'Thank you for reaching out, User. I have noted this on your policy docket (${widget.cover.policyNumber}). Is there anything else you need assistance with?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: CachedNetworkImage(
                        imageUrl: widget.agent.avatarUrl,
                        width: 44.0,
                        height: 44.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.agent.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.cover.underwriter} • Online',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 24),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),

          // Quick Prompt Chips
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('Check my claim status'),
                  const SizedBox(width: 8),
                  _buildQuickChip('When will payout be made?'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Police docket verified?'),
                ],
              ),
            ),
          ),

          // Messages View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAgent = msg['fromAgent'] as bool;
                return Align(
                  alignment:
                      isAgent ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 11.0),
                    decoration: BoxDecoration(
                      color: isAgent
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFFF5500),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: isAgent
                            ? const Radius.circular(3.0)
                            : const Radius.circular(16.0),
                        bottomRight: isAgent
                            ? const Radius.circular(16.0)
                            : const Radius.circular(3.0),
                      ),
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: TextStyle(
                        color:
                            isAgent ? const Color(0xFF0F172A) : Colors.white,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing Indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Text('Assessor is typing...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              16.0,
              10.0,
              16.0,
              MediaQuery.of(context).viewInsets.bottom + 12.0,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your message to ${widget.agent.name}...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Color(0xFFFF5500)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5500),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return GestureDetector(
      onTap: () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
