import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../widgets/aurora_background.dart';
import '../widgets/neumorphic_button.dart';
import '../services/logo_dev_service.dart';

class ConsentDashboardScreen extends StatefulWidget {
  const ConsentDashboardScreen({super.key});

  @override
  State<ConsentDashboardScreen> createState() => _ConsentDashboardScreenState();
}

class _ConsentDashboardScreenState extends State<ConsentDashboardScreen> {
  final List<Map<String, dynamic>> _accessors = [
    {
      'id': '1',
      'name': 'Vodacom Underwriter Services',
      'role': 'Policy & Claim Underwriter',
      'data': 'Identity profile, policy number, IMEI history',
      'lastAccess': 'Today at 09:12',
      'status': 'Active',
      'isRevoked': false,
    },
    {
      'id': '2',
      'name': 'SAPS Police Registry API',
      'role': 'Incident Verification',
      'data': 'Police case number: CAS 482/09/2026',
      'lastAccess': 'Today at 09:15',
      'status': 'Active',
      'isRevoked': false,
    },
    {
      'id': '3',
      'name': 'TransUnion Fraud Screening',
      'role': 'Automated Fraud & Blacklist Engine',
      'data': 'Risk score, national handset blacklist check',
      'lastAccess': 'Today at 09:18',
      'status': 'Active',
      'isRevoked': false,
    },
    {
      'id': '4',
      'name': 'iStore Approved Replacement',
      'role': 'Hardware Fulfilment Partner',
      'data': 'Device serial, replacement model allocation',
      'lastAccess': 'Pending review approval',
      'status': 'Standing by',
      'isRevoked': false,
    },
  ];

  void _toggleRevoke(int index) {
    final accessor = _accessors[index];
    final isRevoked = accessor['isRevoked'] as bool;

    if (!isRevoked) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Revoke Data Access?',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Revoking access for "${accessor['name']}" will pause real-time automated verification for your claim.',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            NeumorphicButton(
              height: 42.0,
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              variant: NeumorphicButtonVariant.primaryOrange,
              text: 'Revoke',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  accessor['isRevoked'] = true;
                  accessor['status'] = 'Revoked';
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 0,
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.transparent,
                    content: AwesomeSnackbarContent(
                      title: 'Access Revoked',
                      message: 'Data access for ${accessor['name']} has been suspended.',
                      contentType: ContentType.warning,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else {
      setState(() {
        accessor['isRevoked'] = false;
        accessor['status'] = 'Active';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'Access Restored',
            message: 'Live verification re-enabled for ${accessor['name']}.',
            contentType: ContentType.success,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AuroraBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
            children: [
              // Header
              const Text(
                'Consent Dashboard',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 28.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6.0),
              const Text(
                'Swipe left on any partner to quickly revoke or inspect access.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 20.0),

              // Info card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFFFF5500), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'EasyClaim never shares data with third parties without your explicit cryptographic consent token.',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 13.0, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),

              // Slidable Access List
              ...List.generate(_accessors.length, (index) {
                final item = _accessors[index];
                final isRevoked = item['isRevoked'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: Slidable(
                      key: ValueKey(item['id']),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _toggleRevoke(index),
                            backgroundColor: isRevoked
                                ? const Color(0xFF0055FF)
                                : const Color(0xFFFF5500),
                            foregroundColor: Colors.white,
                            icon: isRevoked ? Icons.check_circle_outline : Icons.block,
                            label: isRevoked ? 'Restore' : 'Revoke',
                          ),
                          SlidableAction(
                            onPressed: (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Audit log exported for ${item['name']}'),
                                  backgroundColor: const Color(0xFFFF5500),
                                ),
                              );
                            },
                            backgroundColor: const Color(0xFFFF5500),
                            foregroundColor: Colors.white,
                            icon: Icons.history_rounded,
                            label: 'Audit Log',
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                BrandLogo(
                                  name: item['name'] as String,
                                  size: 42.0,
                                  borderRadius: 12.0,
                                  padding: 5.0,
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.0,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        item['role'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFFFF5500),
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.5,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isRevoked
                                        ? const Color(0xFFFFECE5)
                                        : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Text(
                                    item['status'] as String,
                                    style: TextStyle(
                                      color: isRevoked
                                          ? const Color(0xFFFF5500)
                                          : const Color(0xFF0055FF),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Data shared: ${item['data']}',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13.0,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Last access: ${item['lastAccess']}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                                const Row(
                                  children: [
                                    Icon(Icons.swipe_left_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Swipe actions',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                NeumorphicButton(
                                  height: 38.0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                  variant: isRevoked
                                      ? NeumorphicButtonVariant.secondaryBlue
                                      : NeumorphicButtonVariant.outlineOrange,
                                  onTap: () => _toggleRevoke(index),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isRevoked ? Icons.check_circle_outline : Icons.block_rounded,
                                        size: 16,
                                        color: const Color(0xFFFF5500),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isRevoked ? 'Restore Access' : 'Revoke Access',
                                        style: TextStyle(
                                          color: const Color(0xFFFF5500),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
