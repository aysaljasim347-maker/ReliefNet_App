// import 'package:disasteraid_pk/features/donor/donor_donation_screen.dart';
// import 'package:disasteraid_pk/features/in_kind/screens/create_in_kind_screen.dart';
// import 'package:disasteraid_pk/features/maps/campaign_map_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../core/auth/auth_provider.dart';
// import '../../core/utils/app_formatters.dart';
// import '../settings/settings_screen.dart';
// import '../campaigns/screens/campaign_list_screen.dart';
// import '../campaigns/services/campaign_service.dart';

// class DonorDashboard extends StatefulWidget {
//   const DonorDashboard({super.key});
//   @override
//   State<DonorDashboard> createState() => _DonorDashboardState();
// }

// class _DonorDashboardState extends State<DonorDashboard> {
//   int _currentIndex = 0;

//   final List<Widget> _screens = [
//     const DonorHomeTab(),
//     const CampaignMapScreen(),
//     const ProfileTab(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         body: IndexedStack(
//           index: _currentIndex,
//           children: _screens,
//         ),
//         bottomNavigationBar: NavigationBar(
//           selectedIndex: _currentIndex,
//           onDestinationSelected: (index) =>
//               setState(() => _currentIndex = index),
//           destinations: const [
//             NavigationDestination(
//               icon: Icon(Icons.home_outlined),
//               selectedIcon: Icon(Icons.home),
//               label: 'Home',
//             ),
//             NavigationDestination(
//               icon: Icon(Icons.map_outlined),
//               selectedIcon: Icon(Icons.map),
//               label: 'Map',
//             ),
//             NavigationDestination(
//               icon: Icon(Icons.person_outline),
//               selectedIcon: Icon(Icons.person),
//               label: 'Profile',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────
// // Home Tab
// // ─────────────────────────────────────────────────────────────
// class DonorHomeTab extends StatefulWidget {
//   const DonorHomeTab({super.key});

//   @override
//   State<DonorHomeTab> createState() => _DonorHomeTabState();
// }

// class _DonorHomeTabState extends State<DonorHomeTab> {
//   final _service = CampaignService();
//   int _activeCampaigns = 0;
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadStats();
//   }

//   Future<void> _loadStats() async {
//     try {
//       final campaigns = await _service.getAllCampaigns();
//       if (mounted) {
//         setState(() {
//           _activeCampaigns =
//               campaigns.where((c) => c.status == 'ACTIVE').length;
//           _loading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final tt = Theme.of(context).textTheme;
//     final user = context.watch<AuthProvider>().user;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard'),
//         scrolledUnderElevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout_outlined),
//             tooltip: 'Logout',
//             onPressed: () => context.read<AuthProvider>().logout(),
//           ),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: _loadStats,
//         child: ListView(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//           children: [
//             // ── Welcome Card ──────────────────────────────────
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     cs.primary,
//                     cs.primary.withValues(alpha: 0.85),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Welcome back,',
//                     style: tt.titleMedium?.copyWith(
//                       color: cs.onPrimary.withValues(alpha: 0.9),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     user?['name'] ?? 'Donor',
//                     style: tt.headlineSmall?.copyWith(
//                       color: cs.onPrimary,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Icon(Icons.volunteer_activism,
//                           color: cs.onPrimary, size: 20),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Make a difference today',
//                         style: tt.bodyMedium?.copyWith(
//                           color: cs.onPrimary.withValues(alpha: 0.9),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 24),

//             // ── Stats Row ─────────────────────────────────────
//             Row(
//               children: [
//                 Expanded(
//                   child: _StatCard(
//                     label: 'Active Campaigns',
//                     value: _loading ? '...' : '$_activeCampaigns',
//                     icon: Icons.campaign,
//                     color: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _StatCard(
//                     label: 'Your Impact',
//                     value: 'Start',
//                     icon: Icons.favorite,
//                     color: cs.primary,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 24),

//             // ── Quick Actions ─────────────────────────────────
//             Text(
//               'Quick Actions',
//               style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),

//             _ActionCard(
//               icon: Icons.campaign_outlined,
//               title: 'Browse Campaigns',
//               subtitle: 'Find causes to support',
//               color: Colors.blue,
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const CampaignListScreen()),
//               ),
//             ),
//             const SizedBox(height: 12),

//             _ActionCard(
//               icon: Icons.receipt_long_outlined,
//               title: 'My Donations',
//               subtitle: 'View history & download receipts',
//               color: Colors.purple,
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const DonorDonationsScreen()),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // ── NEW: In-Kind Donation ─────────────────────────
//             _ActionCard(
//               icon: Icons.inventory_2_outlined,
//               title: 'Donate In-Kind',
//               subtitle: 'Offer goods, food, clothing & more',
//               color: Colors.teal,
//               onTap: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const CreateInKindScreen()),
//               ),
//             ),
//             const SizedBox(height: 12),

//             _ActionCard(
//               icon: Icons.map_outlined,
//               title: 'Campaign Map',
//               subtitle: 'See campaigns near you',
//               color: Colors.orange,
//               onTap: () {
//                 final state =
//                     context.findAncestorStateOfType<_DonorDashboardState>();
//                 state?.setState(() => state._currentIndex = 1);
//               },
//             ),

//             const SizedBox(height: 24),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────
// // Stat Card
// // ─────────────────────────────────────────────────────────────
// class _StatCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color color;

//   const _StatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final tt = Theme.of(context).textTheme;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: color, size: 28),
//           const SizedBox(height: 12),
//           Text(
//             value,
//             style: tt.headlineMedium?.copyWith(
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────
// // Action Card
// // ─────────────────────────────────────────────────────────────
// class _ActionCard extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String subtitle;
//   final Color color;
//   final VoidCallback onTap;

//   const _ActionCard({
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final tt = Theme.of(context).textTheme;

//     return Card(
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: cs.outlineVariant),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: color.withValues(alpha: 0.15),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Icon(icon, color: color, size: 26),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style:
//                           tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle,
//                       style:
//                           tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
//                     ),
//                   ],
//                 ),
//               ),
//               Icon(Icons.arrow_forward_ios,
//                   size: 16, color: cs.onSurfaceVariant),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────
// // Profile Tab
// // ─────────────────────────────────────────────────────────────
// class ProfileTab extends StatelessWidget {
//   const ProfileTab({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user = context.watch<AuthProvider>().user;
//     final cs = Theme.of(context).colorScheme;
//     final tt = Theme.of(context).textTheme;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Profile'),
//         scrolledUnderElevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // Profile Header
//           Center(
//             child: Column(
//               children: [
//                 CircleAvatar(
//                   radius: 48,
//                   backgroundColor: cs.primaryContainer,
//                   child: Text(
//                     AppFormatters.initial(user?['name'], 'D'),
//                     style: tt.headlineLarge?.copyWith(
//                       color: cs.onPrimaryContainer,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   user?['name'] ?? 'Donor',
//                   style:
//                       tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   user?['email'] ?? '',
//                   style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 32),

//           // Menu Items
//           Card(
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//               side: BorderSide(color: cs.outlineVariant),
//             ),
//             child: Column(
//               children: [
//                 ListTile(
//                   leading: const Icon(Icons.edit_outlined),
//                   title: const Text('Edit Profile'),
//                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//                   onTap: () {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Coming soon')),
//                     );
//                   },
//                 ),
//                 const Divider(height: 1),
//                 ListTile(
//                   leading: const Icon(Icons.notifications_outlined),
//                   title: const Text('Settings'),
//                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//                   onTap: () => Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const SettingsScreen()),
//                   ),
//                 ),
//                 const Divider(height: 1),
//                 ListTile(
//                   leading: Icon(Icons.logout, color: cs.error),
//                   title: Text('Logout', style: TextStyle(color: cs.error)),
//                   onTap: () => context.read<AuthProvider>().logout(),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:disasteraid_pk/features/donor/donor_donation_screen.dart';
import 'package:disasteraid_pk/features/in_kind/screens/create_in_kind_screen.dart';
import 'package:disasteraid_pk/features/in_kind/screens/in_kind_requests_screen.dart';
import 'package:disasteraid_pk/features/maps/campaign_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/app_formatters.dart';
import '../settings/settings_screen.dart';
import '../campaigns/screens/campaign_list_screen.dart';
import '../campaigns/services/campaign_service.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});
  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DonorHomeTab(),
    const CampaignMapScreen(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────────────────────
class DonorHomeTab extends StatefulWidget {
  const DonorHomeTab({super.key});

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  final _campaignService = CampaignService();

  int _activeCampaigns = 0;
  int _totalPendingRequests = 0; // sum of pending_requests across all donations
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // Run both calls concurrently with explicit typed futures
      final campaignFuture = _campaignService.getAllCampaigns();
      final inKindFuture = ApiClient.instance.get<dynamic>('/in-kind/my');

      final campaigns = await campaignFuture;
      final inKindRes = await inKindFuture;

      final donations = inKindRes.data is List
          ? inKindRes.data as List
          : (inKindRes.data['data'] as List? ?? []);

      int pending = 0;
      for (final d in donations) {
        pending += (d['pending_requests'] as num? ?? 0).toInt();
      }

      if (mounted) {
        setState(() {
          _activeCampaigns =
              campaigns.where((c) => c.status == 'ACTIVE').length;
          _totalPendingRequests = pending;
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
        title: const Text('Dashboard'),
        scrolledUnderElevation: 0,
        actions: [
          // Bell icon with badge when there are pending requests
          if (_totalPendingRequests > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Badge(
                label: Text('$_totalPendingRequests'),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Pending in-kind requests',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InKindRequestsScreen()),
                    );
                    _loadStats(); // refresh count after returning
                  },
                ),
              ),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Welcome Card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary,
                    cs.primary.withValues(alpha: 0.85),
                  ],
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
                    style: tt.titleMedium?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?['name'] ?? 'Donor',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism,
                          color: cs.onPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Make a difference today',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats Row ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active Campaigns',
                    value: _loading ? '...' : '$_activeCampaigns',
                    icon: Icons.campaign,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                // Pending requests stat — orange when non-zero
                Expanded(
                  child: _StatCard(
                    label: 'Pending Requests',
                    value: _loading ? '...' : '$_totalPendingRequests',
                    icon: Icons.inbox_outlined,
                    color:
                        _totalPendingRequests > 0 ? Colors.orange : Colors.grey,
                    onTap: _totalPendingRequests > 0
                        ? () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const InKindRequestsScreen()),
                            );
                            _loadStats();
                          }
                        : null,
                  ),
                ),
              ],
            ),

            // ── Pending requests alert banner ─────────────────
            if (!_loading && _totalPendingRequests > 0) ...[
              const SizedBox(height: 16),
              _PendingRequestsBanner(
                count: _totalPendingRequests,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InKindRequestsScreen()),
                  );
                  _loadStats();
                },
              ),
            ],

            const SizedBox(height: 24),

            // ── Quick Actions ─────────────────────────────────
            Text(
              'Quick Actions',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.campaign_outlined,
              title: 'Browse Campaigns',
              subtitle: 'Find causes to support',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampaignListScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.receipt_long_outlined,
              title: 'My Donations',
              subtitle: 'View history & download receipts',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DonorDonationsScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Donate In-Kind',
              subtitle: 'Offer goods, food, clothing & more',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateInKindScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // In-Kind Requests — badge when pending
            _ActionCard(
              icon: Icons.people_outline,
              title: 'In-Kind Requests',
              subtitle: _totalPendingRequests > 0
                  ? '$_totalPendingRequests beneficiar${_totalPendingRequests == 1 ? 'y has' : 'ies have'} requested your items'
                  : 'See who requested your donated items',
              color: Colors.orange,
              badgeCount: _totalPendingRequests,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InKindRequestsScreen()),
                );
                _loadStats(); // refresh badge after returning
              },
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.map_outlined,
              title: 'Campaign Map',
              subtitle: 'See campaigns near you',
              color: Colors.deepOrange,
              onTap: () {
                final state =
                    context.findAncestorStateOfType<_DonorDashboardState>();
                state?.setState(() => state._currentIndex = 1);
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pending Requests Banner
// ─────────────────────────────────────────────────────────────
class _PendingRequestsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingRequestsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active,
                  color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'person has' : 'people have'} requested your items',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to review and approve',
                    style: tt.bodySmall?.copyWith(color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 26),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: color.withOpacity(0.6)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Action Card  (now supports badgeCount)
// ─────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: badgeCount > 0
              ? Colors.orange.withOpacity(0.6)
              : cs.outlineVariant,
          width: badgeCount > 0 ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon with optional badge
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                backgroundColor: Colors.orange,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodyMedium?.copyWith(
                        color: badgeCount > 0
                            ? Colors.orange[800]
                            : cs.onSurfaceVariant,
                        fontWeight: badgeCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

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
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    AppFormatters.initial(user?['name'], 'D'),
                    style: tt.headlineLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?['name'] ?? 'Donor',
                  style:
                      tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] ?? '',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
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
