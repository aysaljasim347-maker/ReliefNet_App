import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../services/campaign_service.dart';
import '../models/campaign.dart';

class CampaignDetailScreen extends StatefulWidget {
  final int id;
  const CampaignDetailScreen({super.key, required this.id});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final _service = CampaignService();
  final _api = ApiClient();
  Campaign? campaign;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final c = await _service.getCampaign(widget.id);
      setState(() { campaign = c; loading = false; });
    } catch (e) {
      setState(() {
        error = e.toString().replaceAll('Exception: ', '');
        loading = false;
      });
    }
  }

  void _showDonateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DonateSheet(
        campaign: campaign!,
        onSuccess: () {
          _load(); // Refresh campaign to show updated raisedAmount
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error!= null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (campaign == null) return const Scaffold(body: Center(child: Text('Campaign not found')));

    final c = campaign!;

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.imageUrl!= null)
                Image.network(
                  c.imageUrl!,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 240,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 60),
                  ),
                )
              else
                Container(
                  height: 240,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.campaign, size: 60)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(c.category.toUpperCase())),
                        const SizedBox(width: 8),
                        Chip(label: Text(c.status)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(c.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(c.orgName?? 'Verified NGO', style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(c.location?? 'Pakistan', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Raised', style: TextStyle(color: Colors.grey[700])),
                              Text('Goal', style: TextStyle(color: Colors.grey[700])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PKR ${c.raisedAmount.toInt()}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'PKR ${c.targetAmount.toInt()}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: c.progress,
                              minHeight: 10,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${c.percentRaised}% funded'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('About this campaign', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(c.description, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: c.status == 'ACTIVE'? _showDonateDialog : null,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                        icon: const Icon(Icons.favorite),
                        label: Text(
                          c.status == 'ACTIVE'? 'Donate Now' : 'Campaign ${c.status}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class DonateSheet extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onSuccess;

  const DonateSheet({super.key, required this.campaign, required this.onSuccess});

  @override
  State<DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<DonateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _paymentMethod = 'MOCK';
  bool _loading = false;
  final _api = ApiClient();

  final List<int> _quickAmounts = [500, 1000, 5000, 10000];

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _donate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await _api.dio.post('/donations', data: {
        'campaign_id': widget.campaign.id,
        'amount': double.parse(_amountController.text),
        'donor_name': _nameController.text.trim(),
        'donor_email': _emailController.text.trim().isEmpty? null : _emailController.text.trim(),
        'payment_method': _paymentMethod,
        'transaction_id': 'MOCK_${DateTime.now().millisecondsSinceEpoch}', // Replace with real payment gateway
        'is_anonymous': false,
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation successful! Thank you'), backgroundColor: Colors.green),
        );
        widget.onSuccess();
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Donation failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Donate to ${widget.campaign.title}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Quick amounts', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _quickAmounts.map((amt) => ChoiceChip(
                label: Text('PKR $amt'),
                selected: _amountController.text == amt.toString(),
                onSelected: (_) => setState(() => _amountController.text = amt.toString()),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (PKR)',
                prefixText: 'PKR ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                final amt = int.tryParse(v);
                if (amt == null || amt < 100) return 'Min PKR 100';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v!.trim().isEmpty? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField(
              value: _paymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['MOCK', 'JAZZCASH', 'EASYPAISA', 'STRIPE'] // UPPERCASE
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                 .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading? null : _donate,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _loading
               ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Donation', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}