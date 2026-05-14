import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class NgoAidRequestsScreen extends StatefulWidget {
  const NgoAidRequestsScreen({super.key});
  @override
  State<NgoAidRequestsScreen> createState() => _NgoAidRequestsScreenState();
}

class _NgoAidRequestsScreenState extends State<NgoAidRequestsScreen> {
  List _requests = [];
  List _volunteers = [];
  bool _loading = true;
  String? _error;
  String _filter = 'APPROVED';
  final _api = ApiClient();
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.dio.get('/ngos/aid-requests', queryParameters: {'status': _filter}),
        _api.dio.get('/ngos/volunteers'),
      ]);
      if (mounted) {
        setState(() {
          _requests = SafeDataHandler.extractList(results[0].data); // ApiClient unwraps
          _volunteers = SafeDataHandler.extractList(results[1].data);
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load requests'; _loading = false; });
    }
  }

  Future<void> _assignVolunteer(int requestId, int volunteerId, String volunteerName) async {
    try {
      await _api.dio.patch('/ngos/aid-requests/$requestId', data: {
        'status': 'ASSIGNED',
        'volunteer_id': volunteerId,
      });
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned to $volunteerName'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _updateStatus(int requestId, String newStatus) async {
    try {
      await _api.dio.patch('/ngos/aid-requests/$requestId', data: {'status': newStatus});
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $newStatus'),
          backgroundColor: Colors.blue,
        ),
      );
      _loadData();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _showError(String msg) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.deepOrange;
      case 'MEDIUM': return Colors.amber[700]!;
      default: return Colors.green;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.blue;
      case 'ASSIGNED': return Colors.teal;
      case 'DELIVERED': return Colors.purple;
      case 'FULFILLED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: ['APPROVED', 'ASSIGNED', 'DELIVERED', 'FULFILLED', 'REJECTED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _loadData(); },
                ),
              )
            ).toList(),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildBody(cs, tt),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadData);
    if (_requests.isEmpty) return _buildEmptyState(cs, tt);
    return _buildRequestList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) {
    return EmptyState(
      icon: Icons.assignment_outlined,
      title: 'No $_filter requests',
      subtitle: _filter == 'APPROVED'
      ? 'Approve beneficiary requests to assign volunteers'
        : 'Requests will appear here',
    );
  }

  Widget _buildRequestList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, i) {
          final r = _requests[i];
          final items = SafeDataHandler.extractList(r['items_needed']).join(', ');
          final displayItems = items.isNotEmpty ? items : (r['category'] ?? 'Aid');
          final urgencyColor = _urgencyColor(r['urgency']);
          final statusColor = _statusColor(r['status']);

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
                Container(height: 4, color: urgencyColor),
                ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: urgencyColor.withOpacity(0.15),
                    child: Text(
                      r['urgency'][0],
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    r['beneficiary_name']?? 'Unknown',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${r['category']} • Family: ${r['family_size']}',
                        style: tt.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['campaign_title']?? 'General Request',
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r['status'],
                      style: tt.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Details
                          _detailRow(Icons.inventory_2_outlined, 'Items Needed', items),
                          const SizedBox(height: 12),
                          _detailRow(Icons.phone_outlined, 'Phone', r['beneficiary_phone']?? 'N/A'),
                          const SizedBox(height: 12),
                          _detailRow(Icons.location_on_outlined, 'Location', r['location']?? 'Unknown'),
                          const SizedBox(height: 12),
                          _detailRow(Icons.notes_outlined, 'Description', r['description']?? 'No description'),
                          const SizedBox(height: 16),

                          // Assigned Volunteer
                          if (r['volunteer_name']!= null)...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline, color: Colors.green[700], size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Assigned to',
                                          style: tt.labelSmall?.copyWith(color: Colors.green[700]),
                                        ),
                                        Text(
                                          '${r['volunteer_name']} • ${r['volunteer_phone']?? 'N/A'}',
                                          style: tt.bodyMedium?.copyWith(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Actions
                          if (_filter == 'APPROVED')...[
                            Text(
                              'Assign Volunteer',
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_volunteers.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No approved volunteers available',
                                        style: tt.bodySmall?.copyWith(color: Colors.orange[700]),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                           ..._volunteers.map((v) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    color: cs.surfaceVariant,
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: cs.primaryContainer,
                                        child: Text(
                                          v['name']?[0].toUpperCase()?? 'V',
                                          style: TextStyle(color: cs.onPrimaryContainer),
                                        ),
                                      ),
                                      title: Text(v['name']?? 'Unknown', style: tt.bodyMedium),
                                      subtitle: Text(v['phone']?? '', style: tt.bodySmall),
                                      trailing: FilledButton(
                                        onPressed: () => _assignVolunteer(r['id'], v['id'], v['name']),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Assign'),
                                      ),
                                    ),
                                  )),
                          ],

                          if (_filter == 'ASSIGNED')...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _updateStatus(r['id'], 'DELIVERED'),
                                icon: const Icon(Icons.local_shipping_outlined),
                                label: const Text('Mark as Delivered'),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],

                          if (_filter == 'DELIVERED')...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _updateStatus(r['id'], 'FULFILLED'),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Mark as Fulfilled'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
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
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}