import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/api_client.dart';
import 'admin_ngos_screen.dart';
import 'admin_campaigns_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final res = await _api.dio.get('/admin/stats');
      setState(() { _stats = res.data['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildStatsTab(),
      AdminNgosScreen(),
      const AdminCampaignsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthProvider>().logout()),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.business), label: 'NGOs'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Campaigns'),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Failed to load stats'), FilledButton(onPressed: _loadStats, child: const Text('Retry'))]));

    final users = _stats!['users'];
    final ngos = _stats!['ngos'];
    final campaigns = _stats!['campaigns'];
    final donations = _stats!['donations'];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Platform Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildStatCard('Total Users', users['total'].toString(), Icons.people, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Donors', users['donors'].toString(), Icons.favorite, Colors.pink)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildStatCard('NGOs Approved', '${ngos['approved']}/${users['ngos']}', Icons.verified, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Pending NGOs', ngos['pending'].toString(), Icons.pending, Colors.orange)),
          ]),
          const Divider(height: 32),
          Text('Campaigns & Donations', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStatCard('Active Campaigns', '${campaigns['active']}/${campaigns['total']}', Icons.campaign, Colors.teal),
          _buildStatCard('Total Raised', 'Rs ${donations['total_amount']?? 0}', Icons.volunteer_activism, Colors.purple),
          _buildStatCard('Total Target', 'Rs ${campaigns['total_target']?? 0}', Icons.flag, Colors.indigo),
          _buildStatCard('Donations Count', donations['total_donations'].toString(), Icons.receipt_long, Colors.brown),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}