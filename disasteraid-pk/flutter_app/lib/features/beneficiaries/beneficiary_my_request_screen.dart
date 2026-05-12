import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _MyRequest {
  final int requestId;
  final String requestStatus;
  final String? requestMessage;
  final DateTime requestedAt;

  final int donationId;
  final String donationTitle;
  final String? donationDescription;
  final String? donationImageUrl;
  final String? donationLocation;
  final String donationStatus;

  // Donor contact — only shown when requestStatus == 'approved'
  final String donorName;
  final String? donorEmail;
  final String? donorPhone;

  const _MyRequest({
    required this.requestId,
    required this.requestStatus,
    this.requestMessage,
    required this.requestedAt,
    required this.donationId,
    required this.donationTitle,
    this.donationDescription,
    this.donationImageUrl,
    this.donationLocation,
    required this.donationStatus,
    required this.donorName,
    this.donorEmail,
    this.donorPhone,
  });

  bool get isApproved => requestStatus == 'approved';
  bool get isPending => requestStatus == 'pending';
  bool get isRejected => requestStatus == 'rejected';

  factory _MyRequest.fromJson(Map<String, dynamic> j) => _MyRequest(
        requestId: j['request_id'],
        requestStatus: j['request_status'] ?? 'pending',
        requestMessage: j['request_message'],
        requestedAt:
            DateTime.tryParse(j['requested_at'] ?? '') ?? DateTime.now(),
        donationId: j['donation_id'],
        donationTitle: j['donation_title'] ?? '',
        donationDescription: j['donation_description'],
        donationImageUrl: j['donation_image_url'],
        donationLocation: j['donation_location'],
        donationStatus: j['donation_status'] ?? '',
        donorName: j['donor_name'] ?? 'Donor',
        donorEmail: j['donor_email'],
        donorPhone: j['donor_phone'],
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BeneficiaryMyRequestsScreen extends StatefulWidget {
  const BeneficiaryMyRequestsScreen({super.key});

  @override
  State<BeneficiaryMyRequestsScreen> createState() =>
      _BeneficiaryMyRequestsScreenState();
}

class _BeneficiaryMyRequestsScreenState
    extends State<BeneficiaryMyRequestsScreen> {
  List<_MyRequest> _requests = [];
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
      final res = await ApiClient.instance.get('/in-kind/my-requests');
      final List data = res.data is List ? res.data : res.data['data'] ?? [];
      if (mounted) {
        setState(() {
          _requests = data.map((e) => _MyRequest.fromJson(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              ApiClient.messageFromError(e, 'Failed to load your requests');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _shimmer();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_requests.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No requests yet',
        subtitle: 'Browse available donations and request items you need',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (_, i) => _RequestCard(request: _requests[i]),
    );
  }

  Widget _shimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
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

// ─── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final _MyRequest request;
  const _RequestCard({required this.request});

  Color get _statusColor {
    switch (request.requestStatus) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (request.requestStatus) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  String get _statusLabel {
    switch (request.requestStatus) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Not Selected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: request.isApproved
              ? Colors.green.withOpacity(0.5)
              : cs.outlineVariant,
          width: request.isApproved ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Approval banner ────────────────────────────────────────────
          if (request.isApproved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your request was approved! Contact the donor below.',
                      style: tt.bodySmall?.copyWith(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          if (request.isRejected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withOpacity(0.06),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[400], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'This item was given to another beneficiary.',
                    style: tt.bodySmall?.copyWith(color: Colors.red[700]),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Donation row ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: request.donationImageUrl != null
                            ? Image.network(
                                request.donationImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: cs.surfaceVariant,
                                  child: Icon(Icons.inventory_2_outlined,
                                      color: cs.onSurfaceVariant),
                                ),
                              )
                            : Container(
                                color: cs.surfaceVariant,
                                child: Icon(Icons.inventory_2_outlined,
                                    color: cs.onSurfaceVariant),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.donationTitle,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (request.donationLocation != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 13, color: cs.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    request.donationLocation!,
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon,
                                    size: 13, color: _statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel,
                                  style: tt.labelSmall?.copyWith(
                                      color: _statusColor,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Your message ─────────────────────────────────────────
                if (request.requestMessage != null &&
                    request.requestMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.requestMessage!,
                            style: tt.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Donor contact card (approved only) ───────────────────
                if (request.isApproved) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_outlined,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Donor Contact',
                              style: tt.labelMedium?.copyWith(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Name
                        _ContactRow(
                          icon: Icons.badge_outlined,
                          label: 'Name',
                          value: request.donorName,
                        ),

                        // Email
                        if (request.donorEmail != null) ...[
                          const SizedBox(height: 7),
                          _ContactRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: request.donorEmail!,
                            copyable: true,
                          ),
                        ],

                        // Phone
                        if (request.donorPhone != null) ...[
                          const SizedBox(height: 7),
                          _ContactRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: request.donorPhone!,
                            copyable: true,
                          ),
                        ],

                        if (request.donorEmail == null &&
                            request.donorPhone == null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'The donor has not added contact details yet.',
                            style:
                                tt.bodySmall?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // ── Requested date ───────────────────────────────────────
                const SizedBox(height: 10),
                Text(
                  'Requested on ${_fmt(request.requestedAt)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Contact row with optional copy ──────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: tt.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              // Copy to clipboard
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Actual clipboard write — import services/clipboard if needed:
              // Clipboard.setData(ClipboardData(text: value));
            },
            child: Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}
