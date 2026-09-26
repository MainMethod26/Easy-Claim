import 'package:flutter/material.dart';
import '../services/logo_dev_service.dart';

class InsurerProfileScreen extends StatefulWidget {
  final String insurerName;

  const InsurerProfileScreen({super.key, required this.insurerName});

  @override
  State<InsurerProfileScreen> createState() => _InsurerProfileScreenState();
}

class _InsurerProfileScreenState extends State<InsurerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.insurerName,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF5500),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFFF5500),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Services'),
            Tab(text: 'Plans'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServicesTab(),
          _buildPlansTab(),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildServiceCard('File a Claim', Icons.note_add_rounded, 'Start a new claim against an active policy.'),
        _buildServiceCard('Cancel Policy', Icons.cancel_rounded, 'Submit a cancellation request.'),
        _buildServiceCard('Update Details', Icons.edit_document, 'Update banking or personal information.'),
        _buildServiceCard('Request Documents', Icons.file_download_rounded, 'Get policy schedules and tax certificates.'),
      ],
    );
  }

  Widget _buildServiceCard(String title, IconData icon, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, color: const Color(0xFFFF5500), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
        ],
      ),
    );
  }

  Widget _buildPlansTab() {
    final plans = [
      {'name': 'Comprehensive Vehicle Cover', 'desc': 'Full protection for your car against accidents, theft, and third-party liabilities.', 'icon': Icons.directions_car_rounded},
      {'name': 'Home Contents Guard', 'desc': 'Secure your valuable household items against theft and natural disasters.', 'icon': Icons.home_rounded},
      {'name': 'Mobile Device Shield', 'desc': 'Screen repair and full replacement for flagship smartphones.', 'icon': Icons.smartphone_rounded},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(plan['icon'] as IconData, color: const Color(0xFF0F172A), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      plan['name'] as String,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan['desc'] as String,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showApplySheet(context, plan['name'] as String);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Apply for Coverage', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApplySheet(BuildContext context, String planName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            title: const Text('Coverage Application', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Applying for: $planName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Your ID (9402185249081) and account details will be securely transmitted to the insurer.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 24),
                const Text('Additional Info Needed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter estimated asset value (R)',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF16A34A),
                          content: Text('Application for $planName sent to ${widget.insurerName}. They will contact you shortly.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5500),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
