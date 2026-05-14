import 'dart:io';
import 'package:dio/dio.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';
import 'package:disasteraid_pk/core/auth/auth_provider.dart';
import 'package:disasteraid_pk/features/chat/screens/chat_screen.dart';
import 'package:disasteraid_pk/features/volunteers/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.dio.get('/volunteers/tasks/available'),
        _api.dio.get('/volunteers/tasks/my'),
      ]);
      if (mounted) {
        setState(() {
          // ApiClient already unwraps {success, data} -> returns array
          _available = results[0].data is List ? List.from(results[0].data) : [];
          _myTasks = results[1].data is List ? List.from(results[1].data) : [];
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final apiErr = e.error as ApiException?;
      if (apiErr?.statusCode == 400 && apiErr?.message == 'Complete volunteer profile first') {
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
          _error = apiErr?.message?? 'Failed to load tasks';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred';
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
      final msg = (e.error as ApiException?)?.message?? 'Failed to accept task';
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
      final msg = (e.error as ApiException?)?.message?? 'Failed to update status';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showDeliveryDialog(int id) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    final proofImage = File(picked.path);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(proofImage, height: 200, fit: BoxFit.cover),
              ),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'PICKED_UP':
        return Colors.orange;
      case 'IN_TRANSIT':
        return Colors.purple;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Tasks'),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
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
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadTasks);
    return TabBarView(
      controller: _tabController,
      children: [_buildAvailableTab(), _buildMyTasksTab()],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(height: 180),
        ),
      ),
    );
  }

  Widget _buildAvailableTab() {
    if (_available.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No available tasks',
        subtitle: 'Check back later for new assignments',
        onAction: _loadTasks,
        actionLabel: 'Refresh',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _available.length,
        itemBuilder: (context, i) => _AvailableTaskCard(
          task: _available[i],
          urgencyColor: _urgencyColor(_available[i]['urgency']?.toString() ?? 'LOW'),
          onAccept: () => _acceptTask(_available[i]['id']),
        ),
      ),
    );
  }

  Widget _buildMyTasksTab() {
    if (_myTasks.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No assigned tasks',
        subtitle: 'Accept tasks from Available tab',
        onAction: () => _tabController.animateTo(0),
        actionLabel: 'View Available',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTasks.length,
        itemBuilder: (context, i) => _MyTaskCard(
          task: _myTasks[i],
          urgencyColor: _urgencyColor(_myTasks[i]['urgency']?.toString() ?? 'LOW'),
          statusColor: _statusColor(_myTasks[i]['status']?.toString() ?? 'ASSIGNED'),
          onUpdateStatus: _updateStatus,
          onShowDelivery: _showDeliveryDialog,
        ),
      ),
    );
  }
}

class _AvailableTaskCard extends StatelessWidget {
  final Map task;
  final Color urgencyColor;
  final VoidCallback onAccept;

  const _AvailableTaskCard({
    required this.task,
    required this.urgencyColor,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = (task['items_needed'] as List?)?.join(', ')?? 'Aid';

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
          // Urgency Bar
          Container(
            height: 4,
            color: urgencyColor,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task['urgency']?.toString() ?? 'LOW',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(task['category']?.toString() ?? 'General'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${task['beneficiary_name'] ?? 'Beneficiary'} - Family of ${task['family_size'] ?? 1}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Campaign: ${task['campaign_title'] ?? 'N/A'}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task['location']?.toString()?? 'Unknown',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Needs: $items', style: tt.bodySmall),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Accept Task'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyTaskCard extends StatelessWidget {
  final Map task;
  final Color urgencyColor;
  final Color statusColor;
  final Function(int, String, {File? proofImage}) onUpdateStatus;
  final Function(int) onShowDelivery;

  const _MyTaskCard({
    required this.task,
    required this.urgencyColor,
    required this.statusColor,
    required this.onUpdateStatus,
    required this.onShowDelivery,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = (task['items_needed'] as List?)?.join(', ')?? 'Aid';
    final status = task['status']?.toString() ?? 'ASSIGNED';
    final canChat = ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'].contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: urgencyColor,
          child: Text(status[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          '${task['category'] ?? 'Aid'} - ${task['beneficiary_name'] ?? 'Beneficiary'}',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(status, style: tt.bodySmall),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _infoRow(context, Icons.campaign_outlined, 'Campaign', task['campaign_title']?.toString() ?? 'N/A'),
                _infoRow(context, Icons.phone_outlined, 'Phone', task['phone']?.toString()?? 'N/A'),
                _infoRow(context, Icons.location_on_outlined, 'Address', task['location']?.toString() ?? 'N/A'),
                _infoRow(context, Icons.people_outline, 'Family Size', '${task['family_size'] ?? 1}'),
                _infoRow(context, Icons.inventory_2_outlined, 'Items', items),
                if (task['assigned_at']!= null)
                  _infoRow(
                    context,
                    Icons.schedule,
                    'Assigned',
                    _parseDate(task['assigned_at']),
                  ),
                const SizedBox(height: 16),
                _buildActionButton(context, task, status, canChat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _parseDate(dynamic value) {
    try {
      if (value == null) return 'N/A';
      return DateTime.parse(value.toString()).toLocal().toString().substring(0, 16);
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Map t, String status, bool canChat) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'ASSIGNED')
          FilledButton.icon(
            onPressed: () => onUpdateStatus(t['id'], 'PICKED_UP'),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Mark Picked Up'),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )
        else if (status == 'PICKED_UP')
          FilledButton.icon(
            onPressed: () => onUpdateStatus(t['id'], 'IN_TRANSIT'),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Mark In Transit'),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )
        else if (status == 'IN_TRANSIT')
          FilledButton.icon(
            onPressed: () => onShowDelivery(t['id']),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Mark Delivered + Photo'),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )
        else if (status == 'DELIVERED')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('Completed', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (canChat)...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId: t['id'],
                    otherUserName: t['beneficiary_name']?? 'Beneficiary',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Chat with Beneficiary'),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ],
    );
  }
}