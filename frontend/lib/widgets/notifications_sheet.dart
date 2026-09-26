import 'package:flutter/material.dart';
import 'neumorphic_button.dart';
import '../services/logo_dev_service.dart';

class NotificationsSheet extends StatefulWidget {
  final VoidCallback? onViewStagesTapped;

  const NotificationsSheet({
    super.key,
    this.onViewStagesTapped,
  });

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'Review Stage: Auto-Approval Qualified',
      'body': 'Claim #EC-482 routed to Fast-Lane Review. R4,200 under R5,000 threshold.',
      'time': '10 mins ago',
      'icon': Icons.bolt_rounded,
      'isOrange': true,
      'isUnread': true,
    },
    {
      'id': '2',
      'title': 'Police Case Verified',
      'body': 'CAS 482/09/2026 confirmed through SAPS National Registry API integration.',
      'time': '45 mins ago',
      'icon': Icons.verified_user_rounded,
      'isOrange': false,
      'isUnread': true,
    },
    {
      'id': '3',
      'title': 'Payout Account Validated',
      'body': 'Standard Bank ending in •••• 4812 confirmed for automated settlement.',
      'time': '2 hours ago',
      'icon': Icons.account_balance_wallet_rounded,
      'isOrange': true,
      'isUnread': true,
    },
    {
      'id': '4',
      'title': 'Vodacom Handset IMEI Blacklisted',
      'body': 'IMEI 354892019482910 blocked nationally to prevent unauthorized SIM use.',
      'time': 'Yesterday at 17:30',
      'icon': Icons.phonelink_lock_rounded,
      'isOrange': false,
      'isUnread': false,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item['isUnread'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.0)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          const SizedBox(height: 18.0),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.0),
                    Text(
                      'Live claim activity and SLA status',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Color(0xFFFF5500),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Notification Items
          ...List.generate(_notifications.length, (index) {
            final item = _notifications[index];
            final isOrange = item['isOrange'] as bool;
            final isUnread = item['isUnread'] as bool;

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: isUnread
                    ? (isOrange ? const Color(0xFFFFF0E6) : const Color(0xFFEFF6FF))
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isUnread
                      ? (isOrange ? const Color(0xFFFF5500).withValues(alpha: 0.3) : const Color(0xFF0055FF).withValues(alpha: 0.3))
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandLogo(
                    name: _getNotificationBrand(item['title'] as String, item['body'] as String),
                    size: 40.0,
                    borderRadius: 12.0,
                    padding: 5.0,
                    fallbackIcon: item['icon'] as IconData,
                    fallbackIconColor: isOrange ? const Color(0xFFFF5500) : const Color(0xFFFF5500),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 7.0,
                                height: 7.0,
                                decoration: BoxDecoration(
                                  color: isOrange ? const Color(0xFFFF5500) : const Color(0xFF0055FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          item['body'] as String,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          item['time'] as String,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10.0),

          // Bottom Close / View Stages Button
          SizedBox(
            width: double.infinity,
            child: NeumorphicButton(
              height: 48.0,
              variant: NeumorphicButtonVariant.primaryOrange,
              text: 'View Live Stages',
              icon: Icons.alt_route_rounded,
              onTap: () {
                Navigator.pop(context);
                widget.onViewStagesTapped?.call();
              },
            ),
          ),
          const SizedBox(height: 12.0),
        ],
      ),
      ),
    );
  }

  String _getNotificationBrand(String title, String body) {
    final t = '$title $body'.toLowerCase();
    if (t.contains('saps') || t.contains('police')) return 'saps';
    if (t.contains('standard bank') || t.contains('payout') || t.contains('account')) return 'standard bank';
    if (t.contains('vodacom')) return 'vodacom';
    if (t.contains('apple') || t.contains('ec-482') || t.contains('fast-lane')) return 'apple';
    return 'apple';
  }
}
