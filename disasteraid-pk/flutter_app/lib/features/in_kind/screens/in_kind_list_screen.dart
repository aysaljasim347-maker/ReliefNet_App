import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/in_kind_donation.dart';
import '../services/in_kind_service.dart';
import 'in_kind_detail_screen.dart';

class InKindListScreen extends StatefulWidget {
  const InKindListScreen({super.key});

  @override
  State<InKindListScreen> createState() => _InKindListScreenState();
}

class _InKindListScreenState extends State<InKindListScreen> {
  final _service = InKindService();
  List<InKindDonation> _donations = [];
  List<InKindDonation> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getAvailableDonations();
      if (mounted) {
        setState(() {
          _donations = data;
          _filtered = data;
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
          _error = ApiClient.messageFromError(e, 'Failed to load donations');
          _loading = false;
        });
      }
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _donations
          : _donations.where((d) {
              return d.title.toLowerCase().contains(q) ||
                  d.location.toLowerCase().contains(q) ||
                  (d.description?.toLowerCase().contains(q) ?? false);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Donations'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Search Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search items or location...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applySearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // ── Count label ──────────────────────────────────────────────────
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} item${_filtered.length == 1 ? '' : 's'} available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_filtered.isEmpty) {
      return EmptyState(
        icon: Icons.volunteer_activism_outlined,
        title: _searchCtrl.text.isNotEmpty
            ? 'No results for "${_searchCtrl.text}"'
            : 'No donations available',
        subtitle: _searchCtrl.text.isNotEmpty
            ? 'Try a different search term'
            : 'Check back later for new items',
        onAction: _searchCtrl.text.isNotEmpty
            ? () {
                _searchCtrl.clear();
                _applySearch();
              }
            : null,
        actionLabel: _searchCtrl.text.isNotEmpty ? 'Clear search' : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _DonationCard(
        donation: _filtered[i],
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InKindDetailScreen(donationId: _filtered[i].id),
            ),
          );
          // Refresh list if beneficiary submitted a request
          if (result == true && mounted) _load();
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(height: 140),
        ),
      ),
    );
  }
}

// ── Donation Card ─────────────────────────────────────────────────────────────

class _DonationCard extends StatelessWidget {
  final InKindDonation donation;
  final VoidCallback onTap;

  const _DonationCard({required this.donation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final daysLeft = donation.expiresAt?.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────────────────
            SizedBox(
              width: 110,
              height: 120,
              child: donation.imageUrl != null
                  ? Image.network(
                      donation.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceVariant,
                        child: Icon(Icons.inventory_2_outlined,
                            color: cs.onSurfaceVariant, size: 32),
                      ),
                    )
                  : Container(
                      color: cs.surfaceVariant,
                      child: Icon(Icons.inventory_2_outlined,
                          color: cs.onSurfaceVariant, size: 32),
                    ),
            ),

            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.title,
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            donation.donorName,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            donation.location,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Bottom row: expiry + arrow ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (daysLeft != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: daysLeft <= 2
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: daysLeft <= 2
                                    ? Colors.red.withOpacity(0.4)
                                    : Colors.orange.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              daysLeft == 0
                                  ? 'Expires today'
                                  : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                              style: tt.labelSmall?.copyWith(
                                color: daysLeft <= 2
                                    ? Colors.red[700]
                                    : Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
