import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/in_kind_donation.dart';
import '../services/in_kind_service.dart';

/// Entry point — shows the donor's list of posted donations.
/// Tapping one opens [_RequestsForDonationScreen].
class InKindRequestsScreen extends StatefulWidget {
  const InKindRequestsScreen({super.key});

  @override
  State<InKindRequestsScreen> createState() => _InKindRequestsScreenState();
}

class _InKindRequestsScreenState extends State<InKindRequestsScreen> {
  final _service = InKindService();
  List<InKindDonation> _donations = [];
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
      final data = await _service.getMyDonations();
      if (mounted) {
        setState(() {
          _donations = data;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'claimed':
        return Colors.blue;
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
        title: const Text('My Donations'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildBody(cs, tt),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_donations.isEmpty) {
      return const EmptyState(
        icon: Icons.volunteer_activism_outlined,
        title: 'No donations posted yet',
        subtitle: 'Post your first in-kind donation from the dashboard',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _donations.length,
      itemBuilder: (context, i) {
        final d = _donations[i];
        return _DonationSummaryCard(
          donation: d,
          statusColor: _statusColor(d.status),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _RequestsForDonationScreen(donation: d),
              ),
            );
            // Refresh counts after returning
            _load();
          },
        );
      },
    );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(height: 110),
        ),
      ),
    );
  }
}

// ── Donation summary card ─────────────────────────────────────────────────────

class _DonationSummaryCard extends StatelessWidget {
  final InKindDonation donation;
  final Color statusColor;
  final VoidCallback onTap;

  const _DonationSummaryCard({
    required this.donation,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: donation.imageUrl != null
                      ? Image.network(donation.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: cs.surfaceVariant,
                                child: Icon(Icons.inventory_2_outlined,
                                    color: cs.onSurfaceVariant),
                              ))
                      : Container(
                          color: cs.surfaceVariant,
                          child: Icon(Icons.inventory_2_outlined,
                              color: cs.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.title,
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          donation.status[0].toUpperCase() +
                              donation.status.substring(1),
                          style: tt.labelSmall?.copyWith(
                              color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (donation.status == 'available')
                      Text(
                        donation.pendingRequests == 0
                            ? 'No requests yet'
                            : '${donation.pendingRequests} pending request${donation.pendingRequests == 1 ? '' : 's'}',
                        style: tt.bodySmall?.copyWith(
                          color: donation.pendingRequests > 0
                              ? Colors.orange[800]
                              : cs.onSurfaceVariant,
                          fontWeight: donation.pendingRequests > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      )
                    else if (donation.status == 'claimed' &&
                        donation.claimedByName != null)
                      Text(
                        'Claimed by ${donation.claimedByName}',
                        style: tt.bodySmall?.copyWith(color: Colors.blue[700]),
                      ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Requests for a single donation ────────────────────────────────────────────

class _RequestsForDonationScreen extends StatefulWidget {
  final InKindDonation donation;

  const _RequestsForDonationScreen({required this.donation});

  @override
  State<_RequestsForDonationScreen> createState() =>
      _RequestsForDonationScreenState();
}

class _RequestsForDonationScreenState
    extends State<_RequestsForDonationScreen> {
  final _service = InKindService();
  List<InKindRequest> _requests = [];
  bool _loading = true;
  String? _error;
  bool _approving = false;

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
      final data = await _service.getRequestsForDonation(widget.donation.id);
      if (mounted) {
        setState(() {
          _requests = data;
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
          _error = ApiClient.messageFromError(e, 'Failed to load requests');
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(InKindRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'You are approving '),
                  TextSpan(
                    text: request.beneficiaryName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text:
                          '\'s request.\n\nAll other pending requests will be automatically rejected.\n\nYour contact details will be shared with the approved beneficiary.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _approving = true);
    try {
      await _service.approveRequest(
        donationId: widget.donation.id,
        requestId: request.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${request.beneficiaryName} approved & notified with your contact details'),
            backgroundColor: Colors.green,
          ),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiClient.messageFromError(e, 'Failed to approve'))));
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Color _reqStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isClaimed = widget.donation.isClaimed;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.donation.title, overflow: TextOverflow.ellipsis),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Donation status banner ───────────────────────────────────
            if (isClaimed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.donation.claimedByName != null
                            ? 'Donated to ${widget.donation.claimedByName}'
                            : 'This item has been claimed',
                        style: tt.bodyMedium?.copyWith(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? _buildShimmer()
                    : _error != null
                        ? ErrorState(message: _error!, onRetry: _load)
                        : _requests.isEmpty
                            ? const EmptyState(
                                icon: Icons.inbox_outlined,
                                title: 'No requests yet',
                                subtitle:
                                    'Beneficiaries will appear here when they request this item',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _requests.length,
                                itemBuilder: (context, i) {
                                  final r = _requests[i];
                                  return _RequestCard(
                                    request: r,
                                    statusColor: _reqStatusColor(r.status),
                                    donationClaimed: isClaimed,
                                    approving: _approving,
                                    onApprove: r.isPending && !isClaimed
                                        ? () => _approve(r)
                                        : null,
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(height: 130),
        ),
      ),
    );
  }
}

// ── Single request card ───────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final InKindRequest request;
  final Color statusColor;
  final bool donationClaimed;
  final bool approving;
  final VoidCallback? onApprove;

  const _RequestCard({
    required this.request,
    required this.statusColor,
    required this.donationClaimed,
    required this.approving,
    this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: request.isApproved
              ? Colors.green.withOpacity(0.4)
              : cs.outlineVariant,
          width: request.isApproved ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    request.beneficiaryName.isNotEmpty
                        ? request.beneficiaryName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.beneficiaryName,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (request.beneficiaryLocation != null)
                        Text(
                          request.beneficiaryLocation!,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    request.status[0].toUpperCase() +
                        request.status.substring(1),
                    style: tt.labelSmall?.copyWith(
                        color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            // ── Message ──────────────────────────────────────────────────
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${request.message}"',
                  style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],

            // ── Contact info (only after approval) ───────────────────────
            if (request.isApproved) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (request.beneficiaryEmail != null)
                _contactRow(
                    context, Icons.email_outlined, request.beneficiaryEmail!),
              if (request.beneficiaryPhone != null) ...[
                const SizedBox(height: 6),
                _contactRow(
                    context, Icons.phone_outlined, request.beneficiaryPhone!),
              ],
            ],

            // ── Approve button ────────────────────────────────────────────
            if (onApprove != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: approving ? null : onApprove,
                  icon: approving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label:
                      Text(approving ? 'Approving...' : 'Approve This Request'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(value, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
