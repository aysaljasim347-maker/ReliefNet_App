import 'package:disasteraid_pk/features/beneficiaries/beneficiary_my_request_screen.dart';
import 'package:disasteraid_pk/features/beneficiaries/screens/beneficiary_map_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_list_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:disasteraid_pk/features/in_kind/screens/in_kind_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import 'request_aid_screen.dart';
import 'package:flutter/services.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});
  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  int _index = 0;

  final List<Widget> _screens = [
    const MyRequestsTab(),
    const InKindListScreen(), // ← Step 9: Browse in-kind donations
    const BeneficiaryMyRequestsScreen(),
    const BeneficiaryMapScreen(),
    const ChatListScreen(),
    const BeneficiaryProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<ChatBadgeProvider>().unreadCount;

    return SafeArea(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Requests',
            ),
            // ── NEW: In-Kind donations tab ──
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'In-Kind',
            ),
            // NEW TAB
            const NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'My Requests',
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
        floatingActionButton: _index == 0
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RequestAidScreen(campaignId: null),
                    ),
                  );
                  if (result == true && mounted) {
                    final tabState =
                        context.findAncestorStateOfType<_MyRequestsTabState>();
                    tabState?._loadRequests();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Request Aid'),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// My Requests Tab
// ─────────────────────────────────────────────────────────────
class MyRequestsTab extends StatefulWidget {
  const MyRequestsTab({super.key});
  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  List _myRequests = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.dio.get('/aid-requests/my'),
        _api.dio.get('/beneficiary/stats').catchError((_) => Response(requestOptions: RequestOptions(), data: {})),
      ]);

      if (mounted) {
        setState(() {
          final rows = results[0].data is List ? results[0].data as List : const [];
          _myRequests = rows.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
          
          final statsData = results[1].data;
          if (statsData is Map) {
            _stats = Map<String, dynamic>.from(statsData);
          }
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load requests';
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'FULFILLED':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.teal;
      case 'PICKED_UP':
        return Colors.orange;
      case 'IN_TRANSIT':
        return Colors.purple;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber[700]!;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Aid Requests'),
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
        onRefresh: _loadRequests,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBody(cs, tt, user),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt, Map<String, dynamic>? user) {
    if (_loading) return _buildShimmer();
    if (_error != null)
      return ErrorState(message: _error!, onRetry: _loadRequests);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.secondary, cs.secondary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome,',
                style: tt.titleMedium
                    ?.copyWith(color: cs.onSecondary.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 4),
              Text(
                user?['name'] ?? 'Beneficiary',
                style: tt.headlineSmall?.copyWith(
                  color: cs.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.support, color: cs.onSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'We are here to help you',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onSecondary.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── In-Kind banner ────────────────────────────────────
        InkWell(
          onTap: () {
            final state =
                context.findAncestorStateOfType<_BeneficiaryDashboardState>();
            state?.setState(() => state._index = 1);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In-Kind Donations Available',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Browse goods, food & clothing near you',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.teal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Stats Row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Active',
                value:
                    '${_stats['active_requests'] ?? _myRequests.where((r) => [
                          'PENDING',
                          'APPROVED',
                          'ASSIGNED'
                        ].contains(r['status'])).length}',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Fulfilled',
                value:
                    '${_stats['fulfilled_requests'] ?? _myRequests.where((r) => [
                          'FULFILLED',
                          'DELIVERED'
                        ].contains(r['status'])).length}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: '${_stats['total_requests'] ?? _myRequests.length}',
                icon: Icons.inventory,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Requests List
        Text(
          'Your Requests',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (_myRequests.isEmpty)
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No aid requests yet',
            subtitle: 'Tap the + button to request aid',
            onAction: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RequestAidScreen(campaignId: null),
                ),
              );
              if (result == true) _loadRequests();
            },
            actionLabel: 'Request Aid',
          )
        else
          ..._myRequests.map((r) => _RequestCard(
                request: r,
                statusColor: _statusColor(r['status']),
                urgencyColor: _urgencyColor(r['urgency']),
              )),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Container(
                height: 80,
                margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          3,
          (_) => Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────
// Request Card
// ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map request;
  final Color statusColor;
  final Color urgencyColor;

  const _RequestCard({
    required this.request,
    required this.statusColor,
    required this.urgencyColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = (request['items_needed'] as List?)?.join(', ') ?? 'Aid';
    final status = request['status'];
    final canChat = request['volunteer_name'] != null &&
        ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'IN_PROGRESS'].contains(status);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: urgencyColor),
          ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.inventory_2_outlined,
                  color: statusColor, size: 20),
            ),
            title: Text(
              request['campaign_title'] ?? 'General Request',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Items: $items', style: tt.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(status,
                        style: tt.labelSmall?.copyWith(
                            color: statusColor, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Text(
                      'Urgency: ${request['urgency']}',
                      style:
                          tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    if (request['volunteer_name'] != null) ...[
                      _detailRow(context, Icons.person_outline,
                          'Assigned Volunteer', request['volunteer_name']),
                      const SizedBox(height: 12),
                      _detailRow(context, Icons.phone_outlined, 'Contact',
                          request['volunteer_phone'] ?? 'N/A'),
                      const SizedBox(height: 12),
                    ],
                    _detailRow(
                        context,
                        Icons.description_outlined,
                        'Description',
                        request['description'] ?? 'No description'),
                    const SizedBox(height: 12),
                    _detailRow(context, Icons.people_outline, 'Family Size',
                        '${request['family_size']}'),
                    const SizedBox(height: 12),
                    _detailRow(
                        context,
                        Icons.calendar_today_outlined,
                        'Requested',
                        dateFormat
                            .format(DateTime.parse(request['created_at']))),
                    if (request['rejection_reason'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rejection Reason',
                                    style: tt.labelMedium?.copyWith(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(request['rejection_reason'],
                                      style: tt.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (canChat) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  requestId: request['id'],
                                  otherUserName:
                                      request['volunteer_name'] ?? 'Volunteer',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Chat with Volunteer'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────
class BeneficiaryProfileTab extends StatelessWidget {
  const BeneficiaryProfileTab({super.key});

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
                  backgroundColor: cs.secondaryContainer,
                  child: Text(
                    user?['name']?[0].toUpperCase() ?? 'B',
                    style: tt.headlineLarge?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?['name'] ?? 'Beneficiary',
                  style:
                      tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] ?? '',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: const Text('Verified Beneficiary'),
                  avatar: Icon(Icons.verified, size: 16, color: cs.primary),
                  backgroundColor: cs.primaryContainer,
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
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
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
