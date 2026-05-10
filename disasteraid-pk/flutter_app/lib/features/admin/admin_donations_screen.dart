import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/app_formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';

class AdminDonationsScreen extends StatefulWidget {
  const AdminDonationsScreen({super.key});

  @override
  State<AdminDonationsScreen> createState() => _AdminDonationsScreenState();
}

class _AdminDonationsScreenState extends State<AdminDonationsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _pendingDonations = [];
  bool _loading = true;
  String? _error;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await _api.dio.get('/donations/pending');
      final rows = res.data is List ? res.data as List : const [];
      if (!mounted) return;
      setState(() {
        _pendingDonations = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiClient.messageFromError(e, 'Failed to load donations');
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleDonations {
    return _pendingDonations.where((donation) {
      final created = AppFormatters.tryParseDate(donation['created_at']);
      if (created == null) return true;
      if (_fromDate != null && created.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
        return false;
      }
      if (_toDate != null) {
        final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (created.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _verifyDonation(int donationId, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _showRejectionDialog();
      if (reason == null) return;
    }

    try {
      await _api.dio.patch('/donations/$donationId/verify', data: {
        'status': approve ? 'VERIFIED' : 'REJECTED',
        'rejection_reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Donation verified' : 'Donation rejected'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      _loadPending();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.messageFromError(e, 'Failed to update donation'))),
        );
      }
    }
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Donation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection reason *',
            hintText: 'Invalid screenshot or amount mismatch',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Reason required')),
                );
                return;
              }
              Navigator.pop(dialogContext, reason);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _viewProof(String? url) {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof image unavailable')),
      );
      return;
    }
    final fullUrl = _absoluteUrl(url);
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Payment Proof'),
            actions: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _absoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    final base = _api.dio.options.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$base/$url'.replaceAll(RegExp(r'(?<!:)//+'), '/');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPending,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildBody(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending bank transfers', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(isFrom: true),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_fromDate == null ? 'From date' : AppFormatters.formatDate(_fromDate)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(isFrom: false),
                icon: const Icon(Icons.event_outlined),
                label: Text(_toDate == null ? 'To date' : AppFormatters.formatDate(_toDate)),
              ),
              if (_fromDate != null || _toDate != null)
                IconButton.outlined(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() {
                    _fromDate = null;
                    _toDate = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _AdminDonationsShimmer();
    if (_error != null) {
      return ListView(children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ErrorState(message: _error!, onRetry: _loadPending),
        ),
      ]);
    }
    final visible = _visibleDonations;
    if (visible.isEmpty) {
      return ListView(children: const [
        SizedBox(
          height: 420,
          child: EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No pending donations',
            subtitle: 'All bank transfers are reviewed',
          ),
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      itemBuilder: (ctx, i) {
        final donation = visible[i];
        return AdminDonationCard(
          donation: donation,
          onViewProof: () => _viewProof(donation['proof_of_payment_url']?.toString()),
          onVerify: () => _verifyDonation(_intValue(donation['id']), true),
          onReject: () => _verifyDonation(_intValue(donation['id']), false),
        );
      },
    );
  }
}

class _AdminDonationsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: cs.surfaceContainerHighest,
          highlightColor: cs.surfaceContainerLow,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final VoidCallback onViewProof;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const AdminDonationCard({
    super.key,
    required this.donation,
    required this.onViewProof,
    required this.onVerify,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    AppFormatters.pkrAmount(donation['amount']),
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: const Text('PENDING'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RowText(label: 'Campaign', value: donation['campaign_title']?.toString()),
            _RowText(label: 'NGO', value: donation['org_name']?.toString()),
            _RowText(label: 'Donor', value: donation['donor_name']?.toString()),
            _RowText(label: 'Email', value: donation['donor_email']?.toString()),
            _RowText(label: 'Phone', value: donation['donor_phone']?.toString()),
            _RowText(label: 'Ref', value: donation['bank_reference']?.toString()),
            _RowText(label: 'Date', value: AppFormatters.formatDateTime(donation['created_at'])),
            if ((donation['donor_note']?.toString().trim().isNotEmpty ?? false))
              _RowText(label: 'Note', value: donation['donor_note']?.toString()),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('View Proof'),
                onPressed: onViewProof,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Verify'),
                    onPressed: onVerify,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  final String label;
  final String? value;

  const _RowText({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final display = value == null || value!.trim().isEmpty ? 'N/A' : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(child: Text(display, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}

int _intValue(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? 0;
}
