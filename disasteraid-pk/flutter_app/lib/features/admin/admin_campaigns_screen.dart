import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});
  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  List _campaigns = [];
  bool _loading = true;
  String _filter = 'ALL';
  String? _error;
  final _api = ApiClient();
  final _currency =
      NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> params =
          _filter == 'ALL' ? {} : {'status': _filter};
      final res =
          await _api.dio.get('/admin/campaigns', queryParameters: params);
      if (mounted) {
        setState(() {
          _campaigns = SafeDataHandler.extractList(res.data);
          _loading = false;
        }); // ApiClient unwraps
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load campaigns';
          _loading = false;
        });
    }
  }

  Future<void> _updateStatus(int id, String status, String title) async {
    final confirmed = await _confirmDialog(status, title);
    if (!confirmed) return;

    try {
      await _api.dio
          .patch('/admin/campaigns/$id/status', data: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campaign ${status.toLowerCase()}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCampaigns();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<bool> _confirmDialog(String status, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${_getStatusAction(status)} Campaign?'),
            content: Text(
                'Are you sure you want to ${_getStatusAction(status).toLowerCase()} "$title"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: status == 'COMPLETED'
                    ? FilledButton.styleFrom(backgroundColor: Colors.red)
                    : null,
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _getStatusAction(String status) {
    switch (status) {
      case 'PAUSED':
        return 'Pause';
      case 'ACTIVE':
        return 'Resume';
      case 'COMPLETED':
        return 'Complete';
      default:
        return status;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'FOOD':
        return Colors.orange;
      case 'MEDICAL':
        return Colors.red;
      case 'SHELTER':
        return Colors.brown;
      case 'EDUCATION':
        return Colors.blue;
      default:
        return Colors.purple;
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
            children: ['ALL', 'ACTIVE', 'PAUSED', 'COMPLETED']
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) {
                          setState(() => _filter = f);
                          _loadCampaigns();
                        },
                      ),
                    ))
                .toList(),
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
    if (_error != null)
      return ErrorState(message: _error!, onRetry: _loadCampaigns);
    if (_campaigns.isEmpty) return _buildEmptyState(cs, tt);
    return _buildCampaignList(cs, tt);
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
      icon: Icons.campaign_outlined,
      title: 'No $_filter campaigns',
      subtitle: _filter == 'ALL'
          ? 'Campaigns will appear here once NGOs create them'
          : 'No campaigns found with this status',
    );
  }

  Widget _buildCampaignList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length,
        itemBuilder: (context, i) {
          final c = _campaigns[i];
          final target = _parseAmount(c['target_amount']);
          final raised = _parseAmount(c['raised_amount']);
          final progress = target > 0 ? raised / target : 0.0;
          final status = c['status'] ?? 'ACTIVE';
          final statusColor = _statusColor(status);
          final categoryColor = _categoryColor(c['category']);

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
                // Status Bar
                Container(height: 4, color: statusColor),
                ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.campaign_outlined,
                        color: categoryColor, size: 24),
                  ),
                  title: Text(
                    c['title'] ?? 'Untitled',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        c['org_name'] ?? 'Unknown NGO',
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currency.format(raised)} / ${_currency.format(target)}',
                            style: tt.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c['category'],
                      style: tt.labelSmall?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
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

                          // Details Grid
                          _detailRow(
                              Icons.business_outlined,
                              'NGO',
                              '${c['org_name']} (${c['ngo_email'] ?? 'N/A'})',
                              cs,
                              tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.category_outlined, 'Category',
                              c['category'] ?? 'N/A', cs, tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.location_on_outlined, 'Location',
                              c['location'] ?? 'N/A', cs, tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.calendar_today_outlined, 'Created',
                              _formatDate(c['created_at']), cs, tt),
                          const SizedBox(height: 16),

                          // Actions
                          Row(
                            children: [
                              if (status == 'ACTIVE') ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(
                                        c['id'], 'PAUSED', c['title']),
                                    icon: const Icon(Icons.pause_outlined),
                                    label: const Text('Pause'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (status == 'PAUSED') ...[
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _updateStatus(
                                        c['id'], 'ACTIVE', c['title']),
                                    icon: const Icon(Icons.play_arrow_outlined),
                                    label: const Text('Resume'),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (status != 'COMPLETED')
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(
                                        c['id'], 'COMPLETED', c['title']),
                                    icon:
                                        const Icon(Icons.check_circle_outline),
                                    label: const Text('Complete'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _detailRow(
      IconData icon, String label, String value, ColorScheme cs, TextTheme tt) {
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

  double _parseAmount(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0;
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
