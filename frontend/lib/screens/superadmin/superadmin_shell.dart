import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../data/repositories/admin_repositories.dart';
import '../admin/admin_auth_screen.dart';
import 'superadmin_accounts_screen.dart';
import 'superadmin_claims_screen.dart';
import 'superadmin_dashboard_screen.dart';
import 'superadmin_insurers_screen.dart';

/// Platform admin portal: dashboard, insurers, accounts and a read-only claim view.
/// The backend never lets a SUPERADMIN verify, decide or pay a claim.
class SuperadminShell extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminShell({super.key, this.repository});

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> {
  int _index = 0;
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();

  void _signOut() {
    Session.instance.signOut();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminAuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final actor = Session.instance.actor;
    final titles = ['Platform overview', 'Insurers', 'Accounts', 'All claims'];
    final pages = [
      SuperadminDashboardScreen(repository: _repo),
      SuperadminInsurersScreen(repository: _repo),
      SuperadminAccountsScreen(repository: _repo),
      SuperadminClaimsScreen(repository: _repo),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('${titles[_index]}${actor == null ? '' : ' · ${actor.label}'}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: _signOut)],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.business_outlined), label: 'Insurers'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Claims'),
        ],
      ),
    );
  }
}
