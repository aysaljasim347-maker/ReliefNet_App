import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class RequestAidScreen extends StatefulWidget {
  final int campaignId;
  final String campaignTitle;
  const RequestAidScreen({super.key, required this.campaignId, required this.campaignTitle});

  @override
  State<RequestAidScreen> createState() => _RequestAidScreenState();
}

class _RequestAidScreenState extends State<RequestAidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String _category = 'FOOD';
  String _urgency = 'MEDIUM';
  int _familySize = 1;
  bool _loading = false;
  final _api = ApiClient();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.dio.post('/aid-requests', data: {
        'campaign_id': widget.campaignId,
        'category': _category,
        'description': _descController.text,
        'urgency': _urgency,
        'family_size': _familySize,
        'location': _locationController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Aid')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Campaign: ${widget.campaignTitle}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField(
              value: _category,
              decoration: const InputDecoration(labelText: 'Aid Type', border: OutlineInputBorder()),
              items: ['FOOD', 'MEDICAL', 'SHELTER', 'CLOTHING'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3, validator: (v) => v!.isEmpty? 'Required' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField(
              value: _urgency,
              decoration: const InputDecoration(labelText: 'Urgency', border: OutlineInputBorder()),
              items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => setState(() => _urgency = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(initialValue: '1', decoration: const InputDecoration(labelText: 'Family Size', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => _familySize = int.tryParse(v)?? 1),
            const SizedBox(height: 16),
            TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Address/Location', border: OutlineInputBorder()), validator: (v) => v!.isEmpty? 'Required' : null),
            const SizedBox(height: 32),
            FilledButton(onPressed: _loading? null : _submit, child: _loading? const CircularProgressIndicator() : const Text('Submit Request')),
          ],
        ),
      ),
    );
  }
}
