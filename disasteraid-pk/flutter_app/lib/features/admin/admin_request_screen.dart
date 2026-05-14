import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});
  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List _requests = [];
  List _ngos = [];
  bool _loading = true;
  String _filter = 'PENDING';
  String? _error;
  final _api = ApiClient();
  final _currency = NumberFormat.compact(locale: 'en_PK');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.dio.get('/admin/aid-requests', queryParameters: {'status': _filter}),
        _api.dio.get('/ngos', queryParameters: {'status': 'APPROVED'}),
      ]);
      if (mounted) {
        setState(() {
          _requests = SafeDataHandler.extractList(results[0].data);
          _ngos = SafeDataHandler.extractList(results[1].data);
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load requests'; _loading = false; });
    }
  }

  Future<void> _assignNgo(int requestId, int ngoId, String beneficiaryName, String ngoName) async {
    final confirmed = await _showAssignDialog(beneficiaryName, ngoName);
    if (!confirmed) return;

    try {
      await _api.dio.patch('/admin/aid-requests/$requestId/assign', data: {
        'ngo_id': ngoId,
        'status': 'APPROVED',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned to $ngoName'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<bool> _showAssignDialog(String beneficiaryName, String ngoName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Request?'),
        content: Text('Assign $beneficiaryName\'s request to $ngoName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    )?? false;
  }

  Future<void> _rejectRequest(int requestId, String beneficiaryName) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      await _api.dio.patch('/admin/aid-requests/$requestId/assign', data: {
        'status': 'REJECTED',
        'rejection_reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Duplicate, outside service area, etc',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason required')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
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
      case 'FULFILLED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'PENDING': return Colors.orange;
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
            children: ['PENDING', 'APPROVED', 'ASSIGNED', 'REJECTED', 'FULFILLED'].map((f) =>
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
      icon: Icons.inbox_outlined,
      title: 'No $_filter requests',
      subtitle: _filter == 'PENDING'
    ? 'New beneficiary requests will appear here'
        : 'No requests found with this status',
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
          final isGeneral = r['campaign_id'] == null;
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
                    backgroundColor: urgencyColor.withValues(alpha: 0.15),
                    child: Text(
                      r['urgency'][0],
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r['beneficiary_name']?? 'Unknown',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isGeneral)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GENERAL',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
                        r['location']?? 'Unknown',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Created: ${_formatDate(r['created_at'])}',
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
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

                          // Campaign Link
                          if (r['campaign_title']!= null)...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.campaign_outlined, size: 20, color: cs.onSecondaryContainer),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Campaign Request',
                                          style: tt.labelSmall?.copyWith(color: cs.onSecondaryContainer),
                                        ),
                                        Text(
                                          r['campaign_title'],
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSecondaryContainer,
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

                          // Items
                          _detailRow(Icons.inventory_2_outlined, 'Items Needed', items, cs, tt),
                          const SizedBox(height: 12),

                          // Description
                          Text(
                            'Description',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['description']?? 'No description',
                              style: tt.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Current NGO
                          if (r['org_name']!= null)...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.business_outlined, size: 20, color: Colors.blue[700]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current NGO',
                                          style: tt.labelSmall?.copyWith(color: Colors.blue[700]),
                                        ),
                                        Text(
                                          r['org_name'],
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
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

                          // Assignment Actions
                          if (_filter == 'PENDING')...[
                            Text(
                              'Assign to NGO',
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_ngos.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No approved NGOs available',
                                        style: tt.bodySmall?.copyWith(color: Colors.orange[700]),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                          ..._ngos.map((ngo) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    color: cs.surfaceContainerHighest,
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: cs.primaryContainer,
                                        child: Text(
                                          ngo['org_name']?[0].toUpperCase()?? 'N',
                                          style: TextStyle(color: cs.onPrimaryContainer),
                                        ),
                                      ),
                                      title: Text(ngo['org_name'], style: tt.bodyMedium),
                                      trailing: FilledButton(
                                        onPressed: () => _assignNgo(
                                          r['id'],
                                          ngo['id'],
                                          r['beneficiary_name'],
                                          ngo['org_name'],
                                        ),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Assign'),
                                      ),
                                    ),
                                  )),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _rejectRequest(r['id'], r['beneficiary_name']),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject Request'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],

                          // Rejection Reason
                          if (r['rejection_reason']!= null)...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rejection Reason',
                                        style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(r['rejection_reason'], style: tt.bodyMedium),
                                ],
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

  Widget _detailRow(IconData icon, String label, String value, ColorScheme cs, TextTheme tt) {
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return date.toString().split('T')[0];
    }
  }
}