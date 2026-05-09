import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/location_picker.dart';

class RequestAidScreen extends StatefulWidget {
  final int? campaignId; // nullable for general requests
  final String campaignTitle;
  const RequestAidScreen({super.key, this.campaignId, this.campaignTitle = 'General Request'});

  @override
  State<RequestAidScreen> createState() => _RequestAidScreenState();
}

class _RequestAidScreenState extends State<RequestAidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _familySizeController = TextEditingController(text: '1');

  String _urgency = 'MEDIUM';
  String _category = 'FOOD'; // Primary category for backend
  final List<String> _selectedItems = ['food']; // Detailed items
  bool _loading = false;
  final _api = ApiClient();

  // ADDED: Location fields
  LatLng? _requestLocation;
  String _requestAddress = '';

  final Map<String, String> _itemOptions = {
    'food': 'Food/Rashan',
    'water': 'Clean Water',
    'medicine': 'Medicine',
    'shelter': 'Shelter/Tent',
    'clothing': 'Clothing',
    'hygiene': 'Hygiene Kit',
  };

  final Map<String, String> _categoryMap = {
    'food': 'FOOD',
    'water': 'FOOD',
    'medicine': 'MEDICAL',
    'shelter': 'SHELTER',
    'clothing': 'CLOTHING',
    'hygiene': 'OTHER',
  };

  @override
  void dispose() {
    _descController.dispose();
    _familySizeController.dispose();
    super.dispose();
  }

  void _updateCategory() {
    if (_selectedItems.isNotEmpty) {
      setState(() {
        _category = _categoryMap[_selectedItems.first]?? 'OTHER';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item needed')),
      );
      return;
    }
    if (_requestLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.dio.post('/aid-requests', data: {
        'campaign_id': widget.campaignId, // can be null
        'category': _category, // backend requires this
        'items_needed': _selectedItems,
        'description': _descController.text.trim(),
        'urgency': _urgency,
        'family_size': int.parse(_familySizeController.text),
        'location': _requestAddress, // Changed from _locationController
        'latitude': _requestLocation!.latitude, // ADDED
        'longitude': _requestLocation!.longitude, // ADDED
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Failed to submit request';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'MEDIUM': return Colors.amber;
      default: return Colors.green;
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
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.campaignId == null? 'General Request' : 'Campaign',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          Text(widget.campaignTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('What do you need?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _itemOptions.entries.map((entry) {
                final selected = _selectedItems.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedItems.add(entry.key);
                      } else {
                        _selectedItems.remove(entry.key);
                      }
                      _updateCategory(); // auto-set category from first item
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text('Category: $_category', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 24),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Describe your situation',
                hintText: 'Explain why you need aid...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => v!.trim().length < 10? 'Please describe in at least 10 characters' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField(
                    value: _urgency,
                    decoration: InputDecoration(
                      labelText: 'Urgency',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.warning, color: _urgencyColor(_urgency)),
                    ),
                    items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                    onChanged: (v) => setState(() => _urgency = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _familySizeController,
                    decoration: InputDecoration(
                      labelText: 'Family Size',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final size = int.tryParse(v!);
                      if (size == null || size < 1) return 'Min 1';
                      if (size > 50) return 'Max 50';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            // REMOVED: Old TextFormField for location
            // ADDED: LocationPicker widget
            const SizedBox(height: 16),
            Text('Your Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LocationPicker(
              onLocationPicked: (latLng, address) {
                setState(() {
                  _requestLocation = latLng;
                  _requestAddress = address;
                });
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loading? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              icon: _loading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
              label: Text(_loading? 'Submitting...' : 'Submit Request', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Text(
              'Your request will be reviewed by volunteers and the NGO',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}