import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:disasteraid_pk/features/volunteers/complete_profile_screen.dart';
import 'package:disasteraid_pk/features/volunteers/volunteer_tasks_screen.dart';
import 'package:disasteraid_pk/features/volunteers/volunteer_map_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/api_client.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});
  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VolunteerTasksTab(),
    const VolunteerMapScreen(),
    const ChatListScreen(),
    const VolunteerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<ChatBadgeProvider>().unreadCount;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class VolunteerTasksTab extends StatefulWidget {
  const VolunteerTasksTab({super.key});

  @override
  State<VolunteerTasksTab> createState() => _VolunteerTasksTabState();
}

class _VolunteerTasksTabState extends State<VolunteerTasksTab> {
  final _api = ApiClient();
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await _api.dio.get('/volunteer/stats');
      if (mounted) {
        setState(() {
          _stats = res.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Dashboard'),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.tertiary, cs.tertiary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: tt.titleMedium?.copyWith(color: cs.onTertiary.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?['name']?? 'Volunteer',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism, color: cs.onTertiary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Delivering hope to those in need',
                        style: tt.bodyMedium?.copyWith(color: cs.onTertiary.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active',
                    value: _loading? '...' : '${_stats['active_tasks']?? 0}',
                    icon: Icons.assignment,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    value: _loading? '...' : '${_stats['completed_tasks']?? 0}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Rating',
                    value: _loading? '...' : '${_stats['rating']?? '5.0'}',
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.assignment_outlined,
              title: 'View Tasks',
              subtitle: 'See all assigned deliveries',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VolunteerTasksScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.map_outlined,
              title: 'Task Map',
              subtitle: 'View deliveries on map',
              color: Colors.purple,
              onTap: () {
                // Switch to map tab
                final state = context.findAncestorStateOfType<_VolunteerDashboardState>();
                state?.setState(() => state._currentIndex = 1);
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.qr_code_scanner,
              title: 'Scan Delivery',
              subtitle: 'Verify beneficiary QR code',
              color: Colors.teal,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class VolunteerProfileTab extends StatelessWidget {
  const VolunteerProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.tertiaryContainer,
                  child: Text(
                    user?['name']?[0].toUpperCase()?? 'V',
                    style: tt.headlineLarge?.copyWith(
                      color: cs.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?['name']?? 'Volunteer',
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email']?? '',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: const Text('Verified Volunteer'),
                  avatar: Icon(Icons.verified, size: 16, color: cs.primary),
                  backgroundColor: cs.primaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu Items
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Delivery History'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: cs.error),
                  title: Text('Logout', style: TextStyle(color: cs.error)),
                  onTap: () => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}