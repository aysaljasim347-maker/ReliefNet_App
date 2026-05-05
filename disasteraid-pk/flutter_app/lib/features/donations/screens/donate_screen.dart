import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/api_client.dart';

class DonateScreen extends StatefulWidget {
  final int campaignId;
  final String campaignTitle;
  const DonateScreen({super.key, required this.campaignId, required this.campaignTitle});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _amountController = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String _method = 'MOCK';

  Future<void> _donate() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min donation Rs 100')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.dio.post('/donations', data: {
        'campaign_id': widget.campaignId,
        'amount': amount,
        'payment_method': _method,
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            title: const Text('Donation Successful!'),
            content: Text('Rs ${amount.toInt()} donated to ${widget.campaignTitle}'),
            actions: [FilledButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Done'))],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donate')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Donating to', style: TextStyle(color: Colors.grey[600])),
          Text(widget.campaignTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Text('Amount (PKR)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: 'Rs ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              hintText: '1000',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [500, 1000, 2000, 5000].map((a) =>
              ActionChip(
                label: Text('Rs $a'),
                onPressed: () => _amountController.text = a.toString(),
              )
            ).toList(),
          ),
          const SizedBox(height: 32),
          Text('Payment Method', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: RadioListTile(
              value: 'MOCK',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: const Text('Mock Payment'),
              subtitle: const Text('Test mode - JazzCash coming soon'),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _loading? null : _donate,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: _loading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Donate Now', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
