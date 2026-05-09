import 'dart:io';
import 'package:dio/dio.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';
import 'package:disasteraid_pk/core/auth/auth_provider.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_screen.dart';
import 'package:disasteraid_pk/features/volunteers/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
  String? _error;
  final _api = ApiClient();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.dio.get('/volunteers/tasks/available'),
        _api.dio.get('/volunteers/tasks/my'),
      ]);
      if (mounted) {
        setState(() {
          _available = results[0].data['data'];
          _myTasks = results[1].data['data'];
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data['error'] == 'Complete volunteer profile first') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.response?.data['error']?? 'Failed to load tasks';
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptTask(int id) async {
    try {
      await _api.dio.post('/volunteers/tasks/$id/accept');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted!'), backgroundColor: Colors.green),
        );
        _loadTasks();
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Failed to accept task';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _updateStatus(int id, String status, {File? proofImage}) async {
    try {
      FormData formData;
      if (status == 'DELIVERED' && proofImage!= null) {
        formData = FormData.fromMap({
          'status': status,
          'proof_image': await MultipartFile.fromFile(proofImage.path),
        });
      } else {
        formData = FormData.fromMap({'status': status});
      }

      await _api.dio.patch('/volunteers/tasks/$id/status', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated: $status'), backgroundColor: Colors.green),
        );
        _loadTasks();
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Failed to update status';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showDeliveryDialog(int id) async {
    File? proofImage;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    proofImage = File(picked.path);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(proofImage!, height: 200, fit: BoxFit.cover),
              const SizedBox(height: 16),
              const Text('Upload this photo as delivery proof?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(id, 'DELIVERED', proofImage: proofImage);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'MEDIUM': return Colors.amber;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Available (${_available.length})'),
            Tab(text: 'My Tasks (${_myTasks.length})'),
          ],
        ),
      ),
      body: _loading
     ? const Center(child: CircularProgressIndicator())
        : _error!= null
     ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadTasks, child: const Text('Retry')),
                ],
              ),
            )
            : TabBarView(
                controller: _tabController,
                children: [_buildAvailableTab(), _buildMyTasksTab()],
              ),
    );
  }

  Widget _buildAvailableTab() {
    if (_available.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No available tasks', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Check back later', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _available.length,
        itemBuilder: (context, i) {
          final t = _available[i];
          final items = (t['items_needed'] as List?)?.join(', ')?? 'Aid';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _urgencyColor(t['urgency']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t['urgency'],
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(label: Text(t['category']), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${t['beneficiary_name']} - Family of ${t['family_size']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('Campaign: ${t['campaign_title']}', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(child: Text(t['location']?? 'Unknown', style: TextStyle(color: Colors.grey[600]))),
                  ]),
                  const SizedBox(height: 8),
                  Text('Needs: $items', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _acceptTask(t['id']),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Accept Task'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyTasksTab() {
    if (_myTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No assigned tasks', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Accept tasks from Available tab', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myTasks.length,
        itemBuilder: (context, i) {
          final t = _myTasks[i];
          final items = (t['items_needed'] as List?)?.join(', ')?? 'Aid';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _urgencyColor(t['urgency']),
                child: Text(t['urgency'][0], style: const TextStyle(color: Colors.white)),
              ),
              title: Text('${t['category']} - ${t['beneficiary_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Status: ${t['status']}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.campaign, 'Campaign', t['campaign_title']),
                      _infoRow(Icons.phone, 'Phone', t['phone']?? 'N/A'),
                      _infoRow(Icons.location_on, 'Address', t['location']),
                      _infoRow(Icons.people, 'Family Size', '${t['family_size']}'),
                      _infoRow(Icons.inventory, 'Items', items),
                      if (t['assigned_at']!= null)
                        _infoRow(Icons.schedule, 'Assigned', DateTime.parse(t['assigned_at']).toLocal().toString().substring(0, 16)),
                      const SizedBox(height: 16),
                      _buildActionButton(t),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
Widget _buildActionButton(Map t) {
  final status = t['status'];
  final canChat = ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'].contains(status);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Existing status buttons
      if (status == 'ASSIGNED')
        FilledButton.icon(
          onPressed: () => _updateStatus(t['id'], 'PICKED_UP'),
          icon: const Icon(Icons.shopping_bag),
          label: const Text('Mark Picked Up'),
        )
      else if (status == 'PICKED_UP')
        FilledButton.icon(
          onPressed: () => _updateStatus(t['id'], 'IN_TRANSIT'),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Mark In Transit'),
        )
      else if (status == 'IN_TRANSIT')
        FilledButton.icon(
          onPressed: () => _showDeliveryDialog(t['id']),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Mark Delivered + Photo'),
        )
      else if (status == 'DELIVERED')
        Chip(
          avatar: const Icon(Icons.check, color: Colors.green),
          label: const Text('Completed'),
          backgroundColor: Colors.green[50],
        ),

      // ADD CHAT BUTTON
      if (canChat)...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(
                requestId: t['id'],
                otherUserName: t['beneficiary_name']?? 'Beneficiary',
              ),
            ));
          },
          icon: const Icon(Icons.chat),
          label: const Text('Chat with Beneficiary'),
        ),
      ],
    ],
  );
}

}