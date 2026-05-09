import 'package:disasteraid_pk/features/ngo/ngo_aid_requests_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_campaign_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_dashboard_screen.dart'; // ADD THIS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import 'ngo_withdrawals_screen.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});
  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const NGODashboardScreen(), // REPLACED old _buildDashboardTab
      const NgoCampaignsScreen(),
      const NgoAidRequestsScreen(),
      const NgoWithdrawalsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Campaigns'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Withdrawals'),
        ],
      ),
    );
  }
}