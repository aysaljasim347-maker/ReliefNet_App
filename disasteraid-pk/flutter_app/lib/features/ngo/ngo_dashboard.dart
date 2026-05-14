import 'package:disasteraid_pk/features/ngo/ngo_aid_requests_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_campaign_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_dashboard_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_onboard_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_withdrawals_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_bank_details_screen.dart'; // ADDED
import '../../core/utils/safe_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/api_client.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});
  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  int _index = 0;
  Map<String, dynamic> _ngoProfile = {};
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _api.dio.get('/ngos/me');
      if (mounted) {
        setState(() {
          _ngoProfile = SafeDataHandler.extractMap(res.data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // No profile = go to onboarding
    if (_ngoProfile == null) {
      return const NgoOnboardScreen();
    }

    final status = _ngoProfile!['status'];

    // PENDING = show waiting screen
    if (status == 'PENDING') {
      return _buildPendingScreen();
    }

    // REJECTED = show rejected screen with resubmit option
    if (status == 'REJECTED') {
      return _buildRejectedScreen();
    }

    // APPROVED = show real dashboard
    return _buildApprovedDashboard();
  }

  Widget _buildPendingScreen() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('NGO Dashboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Verification Pending',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Admin is reviewing your documents. This takes 24-48 hours.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ngoProfile!['org_name']?? '',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _checkNgoStatus();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen() {
    final tt = Theme.of(context).textTheme;
    final reason = _ngoProfile!['rejection_reason'];
    return Scaffold(
      appBar: AppBar(title: const Text('NGO Dashboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Verification Rejected',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (reason!= null)...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: Colors.red[900]),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const NgoOnboardScreen()),
                ),
                child: const Text('Resubmit Documents'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovedDashboard() {
    final List<Widget> screens = [
      const NGODashboardScreen(),
      const NgoCampaignsScreen(),
      const NgoAidRequestsScreen(),
      const NgoWithdrawalsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_ngoProfile!['org_name']?? 'NGO Dashboard'),
        scrolledUnderElevation: 0,
        actions: [
          // ADDED: Bank Details button
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Bank Details',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NgoBankDetailsScreen()),
            ).then((saved) {
              if (saved == true) _checkNgoStatus();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Campaigns',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Withdrawals',
          ),
        ],
      ),
    );
  }
}
