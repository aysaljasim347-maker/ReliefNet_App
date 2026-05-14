import 'package:disasteraid_pk/features/donor/model/donation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/safe_data_handler.dart';
import '../campaigns/screens/campaign_detail_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class DonorDonationsScreen extends StatefulWidget {
  const DonorDonationsScreen({super.key});
  @override
  State<DonorDonationsScreen> createState() => _DonorDonationsScreenState();
}

class _DonorDonationsScreenState extends State<DonorDonationsScreen> {
  List<Donation> _donations = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all, verified, pending
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.dio.get('/donations/my');
      // ApiClient already unwraps {success, data} -> returns data array
      final raw = SafeDataHandler.extractList(res.data);
      if (mounted) {
        setState(() {
          _donations = raw.map((e) => Donation.fromJson(SafeDataHandler.extractMap(e))).toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = ApiClient.messageFromError(e, 'Failed to load donations');
        _loading = false;
      });
    }
  }

  List<Donation> get _filteredDonations {
    if (_filter == 'all') return _donations;
    return _donations.where((d) => d.status.toLowerCase() == _filter).toList();
  }

  int get _totalDonated {
    return _donations
    .where((d) => d.status == 'VERIFIED')
      .fold(0, (sum, d) => sum + d.amount);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadReceipt(Donation d) async {
    if (d.receiptUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt not available yet')),
      );
      return;
    }

    final base = _api.dio.options.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final receipt = d.receiptUrl!;
    final url = receipt.startsWith('http') ? receipt : '$base/$receipt'.replaceAll(RegExp(r'(?<!:)//+'), '/');
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open receipt')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open receipt')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: cs.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Donated',
                  style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.pkrAmount(_totalDonated),
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_donations.where((d) => d.status == 'VERIFIED').length} verified donations',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                FilterChip(
                  label: const Text('Verified'),
                  selected: _filter == 'verified',
                  onSelected: (_) => setState(() => _filter = 'verified'),
                ),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _filter == 'pending',
                  onSelected: (_) => setState(() => _filter = 'pending'),
                ),
                FilterChip(
                  label: const Text('Rejected'),
                  selected: _filter == 'rejected',
                  onSelected: (_) => setState(() => _filter = 'rejected'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDonations,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildBody(cs, tt),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadDonations);
    if (_filteredDonations.isEmpty) return _buildEmptyState();
    return _buildList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(height: 140),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: _filter == 'all'? 'No donations yet' : 'No $_filter donations',
      subtitle: _filter == 'all'
      ? 'Support a campaign to see it here'
        : 'Try changing the filter',
      onAction: _filter == 'all'? null : () => setState(() => _filter = 'all'),
      actionLabel: _filter == 'all'? null : 'Show All',
    );
  }

  Widget _buildList(ColorScheme cs, TextTheme tt) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDonations.length,
      itemBuilder: (context, i) {
        final d = _filteredDonations[i];
        return _DonationCard(
          donation: d,
          statusColor: _statusColor(d.status),
          onDownloadReceipt: d.receiptUrl!= null? () => _downloadReceipt(d) : null,
          onTap: d.campaignId == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CampaignDetailScreen(id: d.campaignId!)),
                  ),
        );
      },
    );
  }
}

class _DonationCard extends StatelessWidget {
  final Donation donation;
  final Color statusColor;
  final VoidCallback? onDownloadReceipt;
  final VoidCallback? onTap;

  const _DonationCard({
    required this.donation,
    required this.statusColor,
    this.onDownloadReceipt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donation.campaignTitle,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        donation.orgName,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    donation.status,
                    style: tt.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.pkrAmount(donation.amount),
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDate(donation.createdAt),
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            if (donation.status == 'VERIFIED' && onDownloadReceipt!= null)...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDownloadReceipt,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Receipt'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (donation.verifiedAt!= null)...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Verified ${AppFormatters.formatDate(donation.verifiedAt!)}',
                    style: tt.bodySmall?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ],
            if (donation.status == 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Awaiting admin verification',
                      style: tt.bodySmall?.copyWith(color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            if (donation.status == 'REJECTED')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'Donation was rejected',
                      style: tt.bodySmall?.copyWith(color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
