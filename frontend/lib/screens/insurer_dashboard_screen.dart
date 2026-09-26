import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'insurer_claim_details_screen.dart';

class InsurerDashboardScreen extends StatefulWidget {
  const InsurerDashboardScreen({super.key});

  @override
  State<InsurerDashboardScreen> createState() => _InsurerDashboardScreenState();
}

class _InsurerDashboardScreenState extends State<InsurerDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _claims = [];

  @override
  void initState() {
    super.initState();
    _fetchClaims();
  }

  Future<void> _fetchClaims() async {
    try {
      final response = await http.get(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/claims'),
        headers: AuthService.authHeaders,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _claims = data['claims'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load claims: ${response.body}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${AuthService.currentRole} Dashboard - ${AuthService.currentTenant}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchClaims();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Simple logout
              AuthService.token = null;
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _claims.isEmpty
              ? const Center(child: Text('No claims assigned to your tenant.'))
              : ListView.builder(
                  itemCount: _claims.length,
                  itemBuilder: (context, index) {
                    final claim = _claims[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('Claim ${claim["id"]} - ${claim["status"]}'),
                        subtitle: Text('Policy: ${claim["policy_id"]} | Amount: ${claim["amount_cents"] != null ? "R${(claim["amount_cents"]/100).toStringAsFixed(2)}" : "TBD"}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InsurerClaimDetailsScreen(claim: claim),
                            ),
                          );
                          if (result == true) {
                            _fetchClaims(); // refresh list
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
