import 'package:disasteraid_pk/features/beneficiaries/screens/beneficiary_map_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_list_screen.dart'; // ADD THIS
import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/api/api_client.dart';
import 'request_aid_screen.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});
  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  int _index = 0;

  final List<Widget> _screens = [
    const MyRequestsTab(),
    const BeneficiaryMapScreen(),
    const ChatListScreen(), // ADD THIS
    const BeneficiaryProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<ChatBadgeProvider>().unreadCount; // ADD THIS

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.list_alt), label: 'My Requests'),
          const NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination( // UPDATE THIS
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Chat',
          ),
          const NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _index == 0? FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RequestAidScreen(campaignId: null),
            ),
          );
          if (result == true) {
            // Refresh handled in MyRequestsTab
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Request Aid'),
      ) : null,
    );
  }
}

// Tab 1: My Requests - no changes needed, you already added chat button
class MyRequestsTab extends StatefulWidget {
  const MyRequestsTab({super.key});
  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  List _myRequests = [];
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final res = await _api.dio.get('/aid-requests/my');
      setState(() { _myRequests = res.data['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'FULFILLED': return Colors.blue;
      case 'DELIVERED': return Colors.blue;
      case 'ASSIGNED': return Colors.teal;
      case 'PENDING': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Aid Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _myRequests.isEmpty
       ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No aid requests yet', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('Tap + to request aid', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _myRequests.length,
                itemBuilder: (context, i) {
                  final r = _myRequests[i];
                  final items = (r['items_needed'] as List?)?.join(', ')?? 'Aid';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(r['status']).withOpacity(0.1),
                        child: Icon(Icons.inventory, color: _statusColor(r['status'])),
                      ),
                      title: Text(r['campaign_title']?? 'General Request',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Items: $items'),
                          const SizedBox(height: 4),
                          Text('Urgency: ${r['urgency']} | Family: ${r['family_size']}',
                            style: const TextStyle(fontSize: 12)),
                          Text('Requested: ${r['created_at'].toString().split('T')[0]}',
                            style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(r['status'], style: const TextStyle(fontSize: 11)),
                        backgroundColor: _statusColor(r['status']).withOpacity(0.1),
                        labelStyle: TextStyle(color: _statusColor(r['status'])),
                      ),
children: [
  Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r['volunteer_name']!= null)...[
          Text('Assigned Volunteer', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text('${r['volunteer_name']} - ${r['volunteer_phone']?? 'N/A'}'),
          const SizedBox(height: 12),
        ],
        Text('Description', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(r['description']?? 'No description'),
        if (r['rejection_reason']!= null)...[
          const SizedBox(height: 12),
          Text('Rejection Reason', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700])),
          const SizedBox(height: 4),
          Text(r['rejection_reason'], style: TextStyle(color: Colors.red[700])),
        ],
        if (r['volunteer_name']!= null &&
            ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'IN_PROGRESS'].contains(r['status']))...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId: r['id'],
                    otherUserName: r['volunteer_name']?? 'Volunteer',
                  ),
                ));
              },
              icon: const Icon(Icons.chat),
              label: const Text('Chat with Volunteer'),
            ),
          ),
        ],
      ],
    ),
  ),
],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// Tab 3: Profile - no changes
class BeneficiaryProfileTab extends StatelessWidget {
  const BeneficiaryProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          Center(child: Text(user?['name']?? 'Beneficiary', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text(user?['email']?? '', style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Edit profile screen
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => context.read<AuthProvider>().logout(),
            ),
          ),
        ],
      ),
    );
  }
}