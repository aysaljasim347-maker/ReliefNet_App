import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../models/in_kind_donation.dart';
import '../services/in_kind_service.dart';

class InKindDetailScreen extends StatefulWidget {
  final int donationId;

  const InKindDetailScreen({super.key, required this.donationId});

  @override
  State<InKindDetailScreen> createState() => _InKindDetailScreenState();
}

class _InKindDetailScreenState extends State<InKindDetailScreen> {
  final _service = InKindService();
  InKindDonation? _donation;
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  final _messageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getDonationDetail(widget.donationId);
      if (mounted) {
        setState(() {
          _donation = data;
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
          _error = ApiClient.messageFromError(e, 'Failed to load item');
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Add an optional message to the donor explaining why you need this item.'),
            const SizedBox(height: 16),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. I have 4 children and need warm clothes...',
                border: OutlineInputBorder(),
                labelText: 'Message (optional)',
              ),
              maxLines: 3,
              maxLength: 300,
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
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await _service.requestDonation(
        widget.donationId,
        message:
            _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent! The donor will review it.'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload to show updated myRequest state
        await _load();
        // Also signal list screen to refresh
        if (mounted) Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(ApiClient.messageFromError(e, 'Failed to send request'))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_donation == null) return const SizedBox.shrink();

    final d = _donation!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final myReq = d.myRequest;
    final alreadyRequested = myReq != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ── Hero Image ────────────────────────────────────────────────
              if (d.imageUrl != null)
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: Image.network(
                    d.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 240,
                      color: cs.surfaceVariant,
                      child: Icon(Icons.inventory_2_outlined,
                          size: 64, color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  color: cs.surfaceVariant,
                  child: Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 64, color: cs.onSurfaceVariant),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title + status ────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            d.title,
                            style: tt.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusChip(status: d.status),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Info rows ─────────────────────────────────────────
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Donor',
                      value: d.donorName,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Pickup Location',
                      value: d.location,
                    ),
                    if (d.expiresAt != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Available Until',
                        value:
                            '${d.expiresAt!.day}/${d.expiresAt!.month}/${d.expiresAt!.year}',
                        valueColor:
                            d.expiresAt!.difference(DateTime.now()).inDays <= 2
                                ? Colors.red
                                : null,
                      ),
                    ],
                    if (d.totalRequests > 0) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.people_outline,
                        label: 'Requests',
                        value:
                            '${d.totalRequests} beneficiar${d.totalRequests == 1 ? 'y' : 'ies'} requested this',
                      ),
                    ],

                    // ── Description ───────────────────────────────────────
                    if (d.description != null && d.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.description!,
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],

                    // ── My request status ─────────────────────────────────
                    if (alreadyRequested) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _MyRequestBanner(request: myReq!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bottom Action Bar ──────────────────────────────────────────────
        if (!d.isClaimed && !d.isExpired)
          _BottomBar(
            alreadyRequested: alreadyRequested,
            myRequestStatus: myReq?.status,
            submitting: _submitting,
            onRequest: _sendRequest,
          ),
      ],
    );
  }

  Widget _buildSkeleton() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(height: 240, color: cs.surfaceVariant),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 28, width: double.infinity, color: cs.surfaceVariant),
              const SizedBox(height: 12),
              Container(height: 16, width: 160, color: cs.surfaceVariant),
              const SizedBox(height: 8),
              Container(height: 16, width: 200, color: cs.surfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'available':
        color = Colors.green;
        label = 'Available';
        break;
      case 'claimed':
        color = Colors.blue;
        label = 'Claimed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MyRequestBanner extends StatelessWidget {
  final dynamic request; // _MyRequest

  const _MyRequestBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    Color color;
    IconData icon;
    String title;
    String subtitle;

    switch (request.status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        title = 'Your request was approved!';
        subtitle = 'Check your notifications for the donor\'s contact details.';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        title = 'Request not selected';
        subtitle = 'The donor chose another beneficiary this time.';
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top_outlined;
        title = 'Request pending';
        subtitle = 'The donor will review your request shortly.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        tt.bodySmall?.copyWith(color: color.withOpacity(0.8))),
                if (request.message != null && request.message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your message: "${request.message}"',
                    style: tt.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool alreadyRequested;
  final String? myRequestStatus;
  final bool submitting;
  final VoidCallback onRequest;

  const _BottomBar({
    required this.alreadyRequested,
    required this.myRequestStatus,
    required this.submitting,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: alreadyRequested || submitting ? null : onRequest,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor:
                  alreadyRequested ? _statusBgColor(myRequestStatus) : null,
            ),
            child: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    alreadyRequested
                        ? _buttonLabel(myRequestStatus)
                        : 'Request This Item',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  String _buttonLabel(String? status) {
    switch (status) {
      case 'approved':
        return '✓ Request Approved';
      case 'rejected':
        return 'Request Not Selected';
      default:
        return 'Request Pending…';
    }
  }

  Color? _statusBgColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
