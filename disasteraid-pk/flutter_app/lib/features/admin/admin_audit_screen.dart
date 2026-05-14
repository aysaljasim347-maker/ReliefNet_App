import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});
  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  List _logs = [];
  bool _loading = true;
  String _filter = 'all';
  String? _error;
  final _api = ApiClient();

  final _actions = ['all', 'APPROVE_NGO', 'REJECT_NGO', 'SUSPEND_NGO', 'APPROVE_WITHDRAWAL', 'REJECT_WITHDRAWAL'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get('/admin/audit-logs', queryParameters: {
        'action': _filter == 'all'? null : _filter,
        'limit': 50,
      });
      if (mounted) {
        setState(() { 
          _logs = SafeDataHandler.extractList(res.data); 
          _loading = false; 
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load audit logs'; _loading = false; });
    }
  }

  Color _actionColor(String action) {
    if (action.contains('APPROVE')) return Colors.green;
    if (action.contains('REJECT') || action.contains('SUSPEND') || action.contains('DELETE')) return Colors.red;
    if (action.contains('UPDATE') || action.contains('EDIT')) return Colors.blue;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('APPROVE')) return Icons.check_circle_outline;
    if (action.contains('REJECT')) return Icons.cancel_outlined;
    if (action.contains('SUSPEND')) return Icons.block_outlined;
    if (action.contains('NGO')) return Icons.business_outlined;
    if (action.contains('WITHDRAWAL')) return Icons.account_balance_wallet_outlined;
    if (action.contains('CAMPAIGN')) return Icons.campaign_outlined;
    return Icons.history_outlined;
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
            children: _actions.map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f == 'all'? 'ALL' : f.replaceAll('_', ' ')),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _loadLogs(); },
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
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadLogs);
    if (_logs.isEmpty) return _buildEmptyState(cs, tt);
    return _buildLogList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 100,
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
      icon: Icons.history_outlined,
      title: 'No ${_filter == 'all'? '' : _filter.replaceAll('_', ' ')} logs',
      subtitle: 'Admin actions will appear here',
    );
  }

  Widget _buildLogList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (_, i) {
          final l = _logs[i];
          final actionColor = _actionColor(l['action']);
          final actionIcon = _actionIcon(l['action']);

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
                // Action Color Bar
                Container(height: 4, color: actionColor),
                ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: actionColor.withValues(alpha: 0.15),
                    child: Icon(actionIcon, color: actionColor, size: 22),
                  ),
                  title: Text(
                    '${l['action'].replaceAll('_', ' ')}: ${l['target_name']?? l['target_id']}',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            l['admin_name']?? 'Unknown',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(l['created_at']),
                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

                          // Old Value
                          if (l['old_value']!= null)...[
                            _valueCard(
                              'Old Value',
                              l['old_value'].toString(),
                              Icons.remove_circle_outline,
                              Colors.red,
                              cs, tt,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // New Value
                          if (l['new_value']!= null)...[
                            _valueCard(
                              'New Value',
                              l['new_value'].toString(),
                              Icons.add_circle_outline,
                              Colors.green,
                              cs, tt,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Reason
                          if (l['reason']!= null)...[
                            _valueCard(
                              'Reason',
                              l['reason'],
                              Icons.info_outline,
                              Colors.blue,
                              cs, tt,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Metadata
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.computer_outlined, size: 16, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 8),
                                    Text('IP Address', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                                    const Spacer(),
                                    Text(
                                      l['ip_address']?? 'N/A',
                                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.fingerprint_outlined, size: 16, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 8),
                                    Text('Log ID', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                                    const Spacer(),
                                    Text(
                                      '#${l['id']}',
                                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  Widget _valueCard(String label, String value, IconData icon, Color color, ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: tt.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return date.toString();
    }
  }
}