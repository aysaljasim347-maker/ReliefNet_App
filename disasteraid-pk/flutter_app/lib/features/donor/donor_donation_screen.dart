import 'package:disasteraid_pk/features/donor/model/donation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';


class DonorDonationsScreen extends StatefulWidget {
  const DonorDonationsScreen({super.key});
  @override
  State<DonorDonationsScreen> createState() => _DonorDonationsScreenState();
}

class _DonorDonationsScreenState extends State<DonorDonationsScreen> {
  List<Donation> _donations = [];
  bool _loading = true;
  String? _error;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get('/donations/my');
      setState(() {
        _donations = (res.data['data'] as List)
           .map((e) => Donation.fromJson(e))
           .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load donations';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'VERIFIED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'PENDING': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<void> _downloadReceipt(Donation d) async {
    if (d.receiptUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt not available yet')),
      );
      return;
    }

    final url = '${_api.dio.options.baseUrl}${d.receiptUrl}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open receipt')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error!= null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadDonations, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_donations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No donations yet', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Support a campaign to get started', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDonations,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _donations.length,
        itemBuilder: (context, i) {
          final d = _donations[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          d.campaignTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Chip(
                        label: Text(d.status, style: const TextStyle(fontSize: 11)),
                        backgroundColor: _statusColor(d.status).withOpacity(0.1),
                        labelStyle: TextStyle(color: _statusColor(d.status)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(d.orgName, style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('PKR ${d.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Date', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(d.createdAt.toString().split(' ')[0]),
                        ],
                      ),
                    ],
                  ),
                  if (d.status == 'VERIFIED' && d.receiptUrl!= null)...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadReceipt(d),
                        icon: const Icon(Icons.download),
                        label: const Text('Download Receipt'),
                      ),
                    ),
                  ],
                  if (d.status == 'PENDING')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Awaiting admin verification', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                    ),
                  if (d.status == 'REJECTED')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Donation was rejected', style: TextStyle(color: Colors.red[700], fontSize: 12)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}