import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List _reports = [];
  bool _loading = true;
  String _filter = 'PENDING';
  String? _error;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get('/admin/reports', queryParameters: {'status': _filter});
      if (mounted) {
        setState(() { 
          _reports = SafeDataHandler.extractList(res.data); 
          _loading = false; 
        }); // ApiClient unwraps
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load reports'; _loading = false; });
    }
  }

  Future<void> _resolve(int id, String status) async {
    final notes = await _showResolveDialog(status);
    if (notes == null || !mounted) return;

    try {
      await _api.dio.patch('/admin/reports/$id', data: {'status': status, 'admin_notes': notes});
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report ${status.toLowerCase()}'),
          backgroundColor: status == 'RESOLVED'? Colors.green : Colors.orange,
        ),
      );
      _loadReports();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<String?> _showResolveDialog(String status) async {
    final controller = TextEditingController();
    final action = status == 'RESOLVED'? 'Resolve' : 'Dismiss';
    final color = status == 'RESOLVED'? Colors.green : Colors.orange;

    if (!mounted || !context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add admin notes for this action:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Admin notes *',
                hintText: 'Action taken, evidence reviewed...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notes required')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'SCAM': return Colors.red;
      case 'FAKE': return Colors.orange;
      case 'HARASSMENT': return Colors.purple;
      case 'INAPPROPRIATE': return Colors.pink;
      case 'SPAM': return Colors.amber[700]!;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESOLVED': return Colors.green;
      case 'DISMISSED': return Colors.grey;
      case 'REVIEWED': return Colors.blue;
      case 'PENDING': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _targetIcon(String targetType) {
    switch (targetType.toLowerCase()) {
      case 'campaign': return Icons.campaign_outlined;
      case 'user': return Icons.person_outline;
      case 'ngo': return Icons.business_outlined;
      case 'message': return Icons.chat_outlined;
      default: return Icons.report_outlined;
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
            children: ['PENDING', 'REVIEWED', 'RESOLVED', 'DISMISSED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _loadReports(); },
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
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadReports);
    if (_reports.isEmpty) return _buildEmptyState(cs, tt);
    return _buildReportList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 120,
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
      icon: Icons.report_outlined,
      title: 'No $_filter reports',
      subtitle: _filter == 'PENDING'
   ? 'User reports will appear here for review'
        : 'No reports found with this status',
    );
  }

  Widget _buildReportList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, i) {
          final r = _reports[i];
          final reasonColor = _reasonColor(r['reason']);
          final statusColor = _statusColor(r['status']);
          final targetIcon = _targetIcon(r['target_type']);

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
                // Severity Bar
                Container(height: 4, color: reasonColor),
                ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: reasonColor.withValues(alpha: 0.15),
                    child: Icon(Icons.flag_outlined, color: reasonColor, size: 22),
                  ),
                  title: Row(
                    children: [
                      Icon(targetIcon, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${r['target_type'].toUpperCase()}: ${r['target_name']?? r['target_id']}',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: reasonColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r['reason'],
                              style: tt.labelSmall?.copyWith(
                                color: reasonColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'by ${r['reporter_name']?? 'Anonymous'}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported: ${_formatDate(r['created_at'])}',
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

                          // Report Details
                          if (r['description']!= null)...[
                            Text(
                              'Report Details',
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
                                r['description'],
                                style: tt.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Admin Notes
                          if (r['admin_notes']!= null)...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.blue[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Admin Notes',
                                        style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(r['admin_notes'], style: tt.bodyMedium),
                                  if (r['resolved_at']!= null)...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Resolved: ${_formatDate(r['resolved_at'])}',
                                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Actions
                          if (_filter == 'PENDING')...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _resolve(r['id'], 'DISMISSED'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Dismiss'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _resolve(r['id'], 'RESOLVED'),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Resolve'),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ],
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return date.toString().split('T')[0];
    }
  }
}