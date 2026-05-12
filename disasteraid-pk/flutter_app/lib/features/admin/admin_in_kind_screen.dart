import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class InKindDonation {
  final int id;
  final String title;
  final String description;
  final String category;
  final String condition;
  final int quantity;
  final String pickupAddress;
  final String status;
  // Donor
  final String donorName;
  final String donorEmail;
  final String? donorPhone;
  // Claimed-by beneficiary (present when status == 'claimed')
  final String? claimedByName;
  final String? claimedByEmail;
  final String? imageUrl;
  final DateTime createdAt;
  final List<InKindRequest> requests;

  InKindDonation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.quantity,
    required this.pickupAddress,
    required this.status,
    required this.donorName,
    required this.donorEmail,
    this.donorPhone,
    this.claimedByName,
    this.claimedByEmail,
    this.imageUrl,
    required this.createdAt,
    required this.requests,
  });

  factory InKindDonation.fromJson(Map<String, dynamic> j) => InKindDonation(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        category: j['category'] ?? '',
        condition: j['condition'] ?? '',
        quantity: j['quantity'] ?? 0,
        pickupAddress: j['location'] ?? j['pickup_address'] ?? '',
        status: j['status'] ?? 'available',
        donorName: j['donor_name'] ?? j['donor']?['name'] ?? 'Unknown',
        donorEmail: j['donor_email'] ?? j['donor']?['email'] ?? '',
        donorPhone: j['donor_phone'],
        claimedByName: j['claimed_by_name'],
        claimedByEmail: j['claimed_by_email'],
        imageUrl: j['image_url'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        requests: (j['requests'] as List<dynamic>? ?? [])
            .map((r) => InKindRequest.fromJson(r))
            .toList(),
      );
}

class InKindRequest {
  final int id;
  final String beneficiaryName;
  final String beneficiaryEmail;
  final String message;
  final String status;
  final DateTime createdAt;

  InKindRequest({
    required this.id,
    required this.beneficiaryName,
    required this.beneficiaryEmail,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory InKindRequest.fromJson(Map<String, dynamic> j) => InKindRequest(
        id: j['id'],
        beneficiaryName:
            j['beneficiary_name'] ?? j['beneficiary']?['name'] ?? 'Unknown',
        beneficiaryEmail:
            j['beneficiary_email'] ?? j['beneficiary']?['email'] ?? '',
        message: j['message'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminInKindScreen extends StatefulWidget {
  const AdminInKindScreen({super.key});

  @override
  State<AdminInKindScreen> createState() => _AdminInKindScreenState();
}

class _AdminInKindScreenState extends State<AdminInKindScreen> {
  static const _statuses = ['ALL', 'available', 'claimed'];

  List<InKindDonation> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';
  String _search = '';

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
      final res = await ApiClient.instance.get('/in-kind/admin/all');
      final List data = res.data is List ? res.data : res.data['data'] ?? [];
      if (mounted) {
        setState(() {
          _all = data.map((e) => InKindDonation.fromJson(e)).toList();
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error =
              e.response?.data?['message'] ?? e.message ?? 'Failed to load';
          _loading = false;
        });
      }
    }
  }

  List<InKindDonation> get _filtered {
    return _all.where((d) {
      final matchStatus = _filter == 'ALL' || d.status == _filter;
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          d.donorName.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q) ||
          (d.claimedByName?.toLowerCase().contains(q) ?? false);
      return matchStatus && matchSearch;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'claimed':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'claimed':
        return Icons.check_circle;
      default:
        return Icons.storefront_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'claimed':
        return 'Claimed';
      default:
        return 'Available';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-Kind Donations'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_loading && _error == null) _StatsBar(donations: _all),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchBar(
                hintText: 'Search by title, donor, beneficiary…',
                leading: const Icon(Icons.search),
                onChanged: (v) => setState(() => _search = v),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16)),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: _statuses.map((s) {
                  final selected = _filter == s;
                  final count = s == 'ALL'
                      ? _all.length
                      : _all.where((d) => d.status == s).length;
                  final label = s == 'ALL'
                      ? 'All ($count)'
                      : '${_statusLabel(s)} ($count)';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = s),
                      selectedColor: s == 'ALL'
                          ? cs.primaryContainer
                          : _statusColor(s).withOpacity(0.25),
                      checkmarkColor: s == 'ALL' ? cs.primary : _statusColor(s),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _search.isNotEmpty
                  ? 'No results for "$_search"'
                  : 'No donations with status "$_filter"',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => _DonationCard(
          donation: items[i],
          statusColor: _statusColor,
          statusIcon: _statusIcon,
          statusLabel: _statusLabel,
        ),
      ),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final List<InKindDonation> donations;
  const _StatsBar({required this.donations});

  @override
  Widget build(BuildContext context) {
    final total = donations.length;
    final available = donations.where((d) => d.status == 'available').length;
    final claimed = donations.where((d) => d.status == 'claimed').length;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Total', value: total, color: Colors.blueGrey),
          _Stat(label: 'Available', value: available, color: Colors.green),
          _Stat(label: 'Claimed', value: claimed, color: Colors.blue),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ─── Donation card ────────────────────────────────────────────────────────────

class _DonationCard extends StatelessWidget {
  final InKindDonation donation;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String) statusLabel;

  const _DonationCard({
    required this.donation,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final d = donation;
    final color = statusColor(d.status);
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: d.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  d.imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 52),
                ),
              )
            : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_outlined, color: color),
              ),
        title:
            Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${d.category} • ${d.condition} • Qty: ${d.quantity}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(d.status), size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(statusLabel(d.status),
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (d.requests.isNotEmpty)
                  Text('${d.requests.length} request(s)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),

        // ── Expanded ────────────────────────────────────────────────────
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Donor section ────────────────────────────────────────
                const _SectionLabel(
                    icon: Icons.volunteer_activism_outlined,
                    label: 'Donor Details'),
                const SizedBox(height: 6),
                _InfoRow(label: 'Name', value: d.donorName),
                _InfoRow(label: 'Email', value: d.donorEmail),
                if (d.donorPhone != null)
                  _InfoRow(label: 'Phone', value: d.donorPhone!),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Pickup',
                    value: d.pickupAddress),
                _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Posted',
                    value:
                        '${d.createdAt.day}/${d.createdAt.month}/${d.createdAt.year}'),
                if (d.description.isNotEmpty)
                  _InfoRow(
                      icon: Icons.notes,
                      label: 'Description',
                      value: d.description),

                // ── Claimed-by section ───────────────────────────────────
                if (d.status == 'claimed' && d.claimedByName != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.how_to_reg,
                                size: 15, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Claimed by Beneficiary',
                              style: tt.labelMedium?.copyWith(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Name', value: d.claimedByName!),
                        if (d.claimedByEmail != null)
                          _InfoRow(label: 'Email', value: d.claimedByEmail!),
                      ],
                    ),
                  ),
                ],

                // ── Requests section ─────────────────────────────────────
                if (d.requests.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text('All Requests (${d.requests.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...d.requests.map((r) => _RequestTile(request: r)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Request tile ─────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final InKindRequest request;
  const _RequestTile({required this.request});

  Color get _color {
    switch (request.status) {
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
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withOpacity(0.15),
          child: Text(
            request.beneficiaryName.isNotEmpty
                ? request.beneficiaryName[0].toUpperCase()
                : '?',
            style: TextStyle(color: _color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(request.beneficiaryName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.beneficiaryEmail,
                style: const TextStyle(fontSize: 11)),
            if (request.message.isNotEmpty)
              Text('"${request.message}"',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700])),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            request.status[0].toUpperCase() + request.status.substring(1),
            style: TextStyle(
                fontSize: 11, color: _color, fontWeight: FontWeight.w600),
          ),
        ),
        isThreeLine: request.message.isNotEmpty,
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey[700])),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  const _InfoRow({this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 5),
          ] else
            const SizedBox(width: 19),
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
