import 'package:disasteraid_pk/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../services/campaign_service.dart';
import '../models/campaign.dart';
import 'campaign_detail_screen.dart';
import 'campaign_create_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});
  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen> {
  final _service = CampaignService();
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getMyCampaigns();
      if (mounted) {
        setState(() {
        _campaigns = list;
        _loading = false;
      });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
        _error = e.message;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = 'Failed to load campaigns';
        _loading = false;
      });
      }
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return cs.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Campaigns'),
        scrolledUnderElevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildBody(cs, tt),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _load);
    if (_campaigns.isEmpty) return _buildEmptyState();
    return _buildCampaignList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(height: 120),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.campaign_outlined,
      title: 'No campaigns yet',
      subtitle: 'Create your first campaign to start raising funds',
      onAction: () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
        );
        if (created == true) _load();
      },
      actionLabel: 'Create Campaign',
    );
  }

  Widget _buildCampaignList(ColorScheme cs, TextTheme tt) {
    // Stats header
    final active = _campaigns.where((c) => c.status == 'ACTIVE').length;
    final totalRaised = _campaigns.fold<double>(0, (sum, c) => sum + c.raisedAmount);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Active',
                  value: '$active',
                  icon: Icons.campaign,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Total Raised',
                  value: 'PKR ${_formatAmount(totalRaised)}',
                  icon: Icons.trending_up,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('All Campaigns', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Campaign Cards
         ..._campaigns.map((c) => _CampaignCard(
                campaign: c,
                statusColor: _statusColor(c.status, cs),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CampaignDetailScreen(id: c.id)),
                  );
                  _load(); // Refresh after returning
                },
              )),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toInt().toString();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final Color statusColor;
  final VoidCallback onTap;

  const _CampaignCard({
    required this.campaign,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      campaign.status,
                      style: tt.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    campaign.category,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      campaign.location?? 'Pakistan',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: campaign.progress,
                  backgroundColor: cs.surfaceVariant,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PKR ${_formatAmount(campaign.raisedAmount as double)}',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${campaign.percentRaised}% of PKR ${_formatAmount(campaign.targetAmount as double)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toInt().toString();
  }
}