import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class InsurerClaimDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> claim;
  const InsurerClaimDetailsScreen({super.key, required this.claim});

  @override
  State<InsurerClaimDetailsScreen> createState() => _InsurerClaimDetailsScreenState();
}

class _InsurerClaimDetailsScreenState extends State<InsurerClaimDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _makeDecision(String status, int? approvedAmount) async {
    setState(() => _isProcessing = true);
    try {
      final response = await http.post(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/claims/${widget.claim["id"]}/decisions'),
        headers: AuthService.authHeaders,
        body: jsonEncode({
          'status': status,
          'approved_amount_cents': approvedAmount,
          'reason': 'Assessed via Insurer Portal'
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim $status successfully')));
          Navigator.pop(context, true); // Return true to refresh dashboard
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error processing request')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _triggerPayout() async {
    setState(() => _isProcessing = true);
    try {
      final response = await http.post(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/claims/${widget.claim["id"]}/pay'),
        headers: AuthService.authHeaders,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout triggered successfully!')));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout Error: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error triggering payout')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final isManager = AuthService.currentRole == 'MANAGER';
    final amountText = claim['amount_cents'] != null ? 'R${(claim["amount_cents"]/100).toStringAsFixed(2)}' : 'TBD';

    return Scaffold(
      appBar: AppBar(
        title: Text('Claim ${claim["id"]}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${claim["status"]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Policy ID: ${claim["policy_id"]}'),
            const SizedBox(height: 8),
            Text('Requested Amount: $amountText'),
            const SizedBox(height: 24),
            
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Action Buttons
              if (claim['status'] == 'Submitted' || claim['status'] == 'Under_Review') ...[
                ElevatedButton(
                  onPressed: () => _makeDecision('Approved', claim['amount_cents']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Approve Claim'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _makeDecision('Rejected', 0),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Reject Claim'),
                ),
              ],
              
              if (claim['status'] == 'Approved' && isManager) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _triggerPayout,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Trigger Payout (Simulated)'),
                ),
              ]
            ]
          ],
        ),
      ),
    );
  }
}
