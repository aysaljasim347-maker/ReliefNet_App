import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class VolunteerTasksScreen extends StatefulWidget {
  const VolunteerTasksScreen({super.key});
  @override
  State<VolunteerTasksScreen> createState() => _VolunteerTasksScreenState();
}

class _VolunteerTasksScreenState extends State<VolunteerTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List _available = [];
  List _myTasks = [];
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final availableRes = await _api.dio.get('/volunteers/tasks/available');
      final myRes = await _api.dio.get('/volunteers/tasks/my');
      setState(() { _available = availableRes.data['data']; _myTasks = myRes.data['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptTask(int id) async {
    try {
      await _api.dio.post('/volunteers/tasks/$id/accept');
      _loadTasks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task accepted!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _api.dio.patch('/volunteers/tasks/$id/status', data: {'status': status});
      _loadTasks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status: $status')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Tasks'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Available'),
          Tab(text: 'My Tasks'),
        ]),
      ),
      body: _loading? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildAvailableTab(),
              _buildMyTasksTab(),
            ],
          ),
    );
  }

  Widget _buildAvailableTab() {
    if (_available.isEmpty) return const Center(child: Text('No available tasks'));
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _available.length,
        itemBuilder: (context, i) {
          final t = _available[i];
          return Card(
            child: ListTile(
              title: Text('${t['category']} - ${t['beneficiary_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t['urgency']} | ${t['campaign_title']}'),
                  Text('Location: ${t['location']}'),
                ],
              ),
              trailing: FilledButton(onPressed: () => _acceptTask(t['id']), child: const Text('Accept')),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyTasksTab() {
    if (_myTasks.isEmpty) return const Center(child: Text('No assigned tasks'));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _myTasks.length,
      itemBuilder: (context, i) {
        final t = _myTasks[i];
        return Card(
          child: ExpansionTile(
            title: Text('${t['category']} - ${t['beneficiary_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${t['status']}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campaign: ${t['campaign_title']}'),
                    Text('Phone: ${t['phone']}'),
                    Text('Address: ${t['location']}'),
                    Text('Family Size: ${t['family_size']}'),
                    const SizedBox(height: 16),
                    if (t['status'] == 'ASSIGNED')
                      FilledButton(onPressed: () => _updateStatus(t['id'], 'PICKED_UP'), child: const Text('Mark Picked Up')),
                    if (t['status'] == 'PICKED_UP')
                      FilledButton(onPressed: () => _updateStatus(t['id'], 'IN_TRANSIT'), child: const Text('Mark In Transit')),
                    if (t['status'] == 'IN_TRANSIT')
                      FilledButton(onPressed: () => _updateStatus(t['id'], 'DELIVERED'), child: const Text('Mark Delivered')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
