import 'package:dio/dio.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String _method = 'JAZZCASH';

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
        'campaign_id': widget.campaignId,
        'amount': double.parse(_amountController.text),
        'donor_name': _nameController.text.trim(),
        'donor_email': _emailController.text.trim().isEmpty? null : _emailController.text.trim(),
        'payment_method': _method,
        'transaction_id': 'MOCK_${DateTime.now().millisecondsSinceEpoch}',
      });
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            title: const Text('Donation Successful!'),
            content: Text('PKR ${_amountController.text} donated to ${widget.campaignTitle}'),
            actions: [FilledButton(onPressed: () { Navigator.pop(context); Navigator.pop(context, true); }, child: const Text('Done'))],
          ),
        );
      }
    } on DioException catch (e) {
      final apiErr = e.error;
      final msg = apiErr is ApiException ? apiErr.message : (e.message ?? 'Donation failed');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donate')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Donating to', style: TextStyle(color: Colors.grey[600])),
            Text(widget.campaignTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
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
            const SizedBox(height: 24),
            Text('Amount (PKR)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: 'PKR ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: '1000',
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                final amt = int.tryParse(v);
                if (amt == null || amt < 10) return 'Min PKR 10';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 5000].map((a) =>
                ActionChip(
                  label: Text('PKR $a'),
                  onPressed: () => _amountController.text = a.toString(),
                )
              ).toList(),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField(
              value: _method,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['JAZZCASH', 'EASYPAISA', 'BANK_TRANSFER', 'STRIPE']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                 .toList(),
              onChanged: (v) => setState(() => _method = v!),
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
      ),
    );
  }
}