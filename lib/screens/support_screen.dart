import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:getwidget/getwidget.dart';
import '../widgets/neumorphic_button.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _selectedSlot = '10:30 AM (In 15m)';

  final List<String> _callSlots = [
    '10:30 AM (In 15m)',
    '11:45 AM',
    '02:15 PM',
    '04:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
            children: [
              // Header
              const Text(
                'Talk to a Person',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 28.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6.0),
              const Text(
                'Direct human support whenever you need assistance.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 20.0),

              // Assigned Claims Specialist Card using CachedNetworkImage
              Container(
                padding: const EdgeInsets.all(16.0),
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
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: CachedNetworkImage(
                        imageUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&q=80',
                        width: 60.0,
                        height: 60.0,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60.0,
                          height: 60.0,
                          color: const Color(0xFFFF5500),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60.0,
                          height: 60.0,
                          color: const Color(0xFFFF5500),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Sarah Dlamini',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.verified, color: Color(0xFF0072FF), size: 16),
                            ],
                          ),
                          const SizedBox(height: 3.0),
                          const Text(
                            'Senior Device Claims Assessor',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Row(
                            children: [
                              Container(
                                width: 7.5,
                                height: 7.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5500),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Online • Typical reply < 3 mins',
                                style: TextStyle(
                                  color: Color(0xFFFF5500),
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
              ),
              const SizedBox(height: 18.0),

              // WhatsApp Support
              _buildSupportCard(
                context,
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFFFF5500),
                title: 'WhatsApp Assistant',
                subtitle: 'Continue Thabo\'s claim or submit evidence via WhatsApp.',
                badge: 'Fastest',
                buttonText: 'Open WhatsApp',
                variant: NeumorphicButtonVariant.primaryOrange,
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      elevation: 0,
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.transparent,
                      content: const AwesomeSnackbarContent(
                        title: 'Connecting WhatsApp',
                        message: 'Opening EasyClaim WhatsApp verified bot...',
                        contentType: ContentType.help,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14.0),

              // Emergency Hotline
              _buildSupportCard(
                context,
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFF0055FF),
                title: 'Claims Hotline (Toll-Free)',
                subtitle: 'Direct priority dial: 0800 242 468.',
                badge: '24/7 Live',
                buttonText: 'Call Now',
                variant: NeumorphicButtonVariant.secondaryBlue,
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      elevation: 0,
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.transparent,
                      content: const AwesomeSnackbarContent(
                        title: 'Calling 0800 242 468',
                        message: 'Connecting to toll-free emergency claims line.',
                        contentType: ContentType.success,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14.0),

              // Schedule Call-Back Card with Slot Picker
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phone_callback_rounded, color: Color(0xFFFF5500), size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Request Free Call-Back',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
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
                      'Choose a convenient time today for an assessor to call you.',
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
                    const SizedBox(height: 16.0),
                    SizedBox(
                      width: double.infinity,
                      child: NeumorphicButton(
                        height: 52.0,
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
                                message: 'Sarah Dlamini will call you at $_selectedSlot.',
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
              const SizedBox(height: 18.0),

              // Appeal & Info Section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: Color(0xFFFF5500), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Have an issue or appeal?',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15.0,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'If a claim is rejected, you have 30 days to lodge an Appeal with additional evidence. The claim directly re-enters Stage 4 (Review) with senior assessor escalation.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
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
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Icon(icon, color: iconColor, size: 26.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
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
          const SizedBox(height: 10.0),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14.0),
          SizedBox(
            width: double.infinity,
            child: NeumorphicButton(
              height: 48.0,
              variant: variant,
              text: buttonText,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
