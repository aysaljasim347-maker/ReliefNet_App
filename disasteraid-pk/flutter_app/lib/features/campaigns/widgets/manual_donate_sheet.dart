import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';

class ManualDonateSheet extends StatefulWidget {
  final int campaignId;
  final String campaignTitle;
  const ManualDonateSheet({super.key, required this.campaignId, required this.campaignTitle});

  @override
  State<ManualDonateSheet> createState() => _ManualDonateSheetState();
}

class _ManualDonateSheetState extends State<ManualDonateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  XFile? _proof;
  bool _loading = false;
  Map<String, dynamic>? _bankDetails;
  final _api = ApiClient();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (img!= null) setState(() => _proof = img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment screenshot')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'campaign_id': widget.campaignId,
        'amount': _amount.text,
        'donor_note': _note.text.trim(),
        'proof': await MultipartFile.fromFile(_proof!.path),
      });

      final res = await _api.dio.post('/donations/manual', data: formData);
      if (mounted) {
        setState(() {
          _bankDetails = res.data; // Already unwrapped by ApiClient
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        final apiErr = e.error as ApiException?;
        final msg = apiErr?.message?? 'Donation failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 8,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _bankDetails!= null? _buildSuccessView(cs, tt) : _buildFormView(cs, tt),
      ),
    );
  }

  Widget _buildSuccessView(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text(
            'Transfer Details',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your donation by transferring to the account below',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                _buildDetailRow('Bank', _bankDetails!['bank_name'], cs, tt),
                Divider(height: 1, color: cs.outlineVariant),
                _buildDetailRow('Account Title', _bankDetails!['account_title'], cs, tt),
                Divider(height: 1, color: cs.outlineVariant),
                _buildDetailRow('Account #', _bankDetails!['account_number'], cs, tt, copy: true),
                Divider(height: 1, color: cs.outlineVariant),
                _buildDetailRow('IBAN', _bankDetails!['iban'], cs, tt, copy: true),
                Divider(height: 1, color: cs.outlineVariant),
                _buildDetailRow(
                  'Amount',
                  'PKR ${_bankDetails!['amount']}',
                  cs,
                  tt,
                  highlight: true,
                ),
                Divider(height: 1, color: cs.outlineVariant),
                _buildDetailRow(
                  'Reference',
                  _bankDetails!['reference'],
                  cs,
                  tt,
                  copy: true,
                  mono: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Important Steps',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStep('1', 'Transfer the exact amount shown above'),
                _buildStep('2', 'Use the reference code in payment notes'),
                _buildStep('3', 'Admin will verify within 24 hours'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Bank Transfer Donation',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'For ${widget.campaignTitle}',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount (PKR)',
                prefixText: 'PKR ',
                border: OutlineInputBorder(),
                helperText: 'Minimum PKR 100',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                final amt = double.tryParse(v);
                if (amt == null || amt < 100) return 'Minimum PKR 100';
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: Icon(_proof == null? Icons.upload_file : Icons.check_circle, color: _proof!= null? Colors.green : null),
              label: Text(_proof == null? 'Upload Payment Screenshot *' : 'Screenshot Selected'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: _proof!= null? Colors.green : cs.outline),
              ),
            ),
            if (_proof!= null) ...[
              const SizedBox(height: 8),
              Text(
                _proof!.name,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add a message or reference',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                  ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Get Transfer Details', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    ColorScheme cs,
    TextTheme tt, {
    bool copy = false,
    bool highlight = false,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: highlight? FontWeight.bold : FontWeight.w600,
                      fontFamily: mono? 'monospace' : null,
                      color: highlight? cs.primary : null,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (copy) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 16, color: cs.primary),
                    ),
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