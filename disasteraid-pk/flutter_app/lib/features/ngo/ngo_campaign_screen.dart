import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:disasteraid_pk/features/campaigns/models/campaign.dart';
import 'package:disasteraid_pk/features/campaigns/screens/campaign_create_screen.dart';
import 'package:disasteraid_pk/features/campaigns/screens/campaign_detail_screen.dart';
import '../../core/api/api_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class NgoCampaignsScreen extends StatefulWidget {
  const NgoCampaignsScreen({super.key});
  @override
  State<NgoCampaignsScreen> createState() => _NgoCampaignsScreenState();
}

class _NgoCampaignsScreenState extends State<NgoCampaignsScreen> {
  final _api = ApiClient();
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String? _error;
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ngoRes = await _api.dio.get('/ngos/me');
      final ngoId = (ngoRes.data as Map?)?['id']; // ApiClient unwraps
      final res = await _api.dio.get('/campaigns', queryParameters: {'ngo_id': ngoId});
      if (mounted) {
        setState(() {
          final rows = res.data is List ? res.data as List : const [];
          _campaigns = rows.map((e) => Campaign.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load campaigns'; _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return Colors.green;
      case 'COMPLETED': return Colors.blue;
      case 'PAUSED': return Colors.orange;
      case 'PENDING': return Colors.amber[700]!;
      default: return Colors.grey;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'FOOD': return Colors.orange;
      case 'MEDICAL': return Colors.red;
      case 'SHELTER': return Colors.brown;
      case 'EDUCATION': return Colors.blue;
      default: return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadCampaigns,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
          );
          if (created == true) _loadCampaigns();
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Campaign'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadCampaigns);
    if (_campaigns.isEmpty) return _buildEmptyState();
    return _buildCampaignList();
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.campaign_outlined,
      title: 'No campaigns yet',
      subtitle: 'Create your first campaign to start receiving donations',
      onAction: () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
        );
        if (created == true) _loadCampaigns();
      },
      actionLabel: 'Create Campaign',
    );
  }

  Widget _buildCampaignList() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _campaigns.length,
      itemBuilder: (context, i) {
        final c = _campaigns[i];
        final progress = c.targetAmount > 0 ? (c.raisedAmount / c.targetAmount).clamp(0.0, 1.0) : 0.0;
        final statusColor = _statusColor(c.status);
        final categoryColor = _categoryColor(c.category);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CampaignDetailScreen(id: c.id),
                ),
              ).then((_) => _loadCampaigns());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          color: categoryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.status,
                                    style: tt.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.category,
                                    style: tt.labelSmall?.copyWith(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Raised',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: cs.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currency.format(c.raisedAmount),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            'raised',
                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currency.format(c.targetAmount),
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'goal',
                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
