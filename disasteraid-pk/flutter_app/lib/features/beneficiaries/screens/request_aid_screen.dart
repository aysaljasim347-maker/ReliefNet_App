import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/location_picker.dart';

class RequestAidScreen extends StatefulWidget {
  final int? campaignId;
  final String campaignTitle;
  const RequestAidScreen(
      {super.key, this.campaignId, this.campaignTitle = 'General Request'});

  @override
  State<RequestAidScreen> createState() => _RequestAidScreenState();
}

class _RequestAidScreenState extends State<RequestAidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _familySizeController = TextEditingController(text: '1');

  String _urgency = 'MEDIUM';
  String _category = 'FOOD';
  final List<String> _selectedItems = ['food'];
  bool _loading = false;
  final _api = ApiClient();

  LatLng? _requestLocation;
  String _requestAddress = '';

  final List<Map<String, dynamic>> _itemOptions = [
    {'key': 'food', 'label': 'Food/Rashan', 'icon': Icons.restaurant_outlined},
    {'key': 'water', 'label': 'Clean Water', 'icon': Icons.water_drop_outlined},
    {
      'key': 'medicine',
      'label': 'Medicine',
      'icon': Icons.medical_services_outlined
    },
    {'key': 'shelter', 'label': 'Shelter/Tent', 'icon': Icons.home_outlined},
    {'key': 'clothing', 'label': 'Clothing', 'icon': Icons.checkroom_outlined},
    {
      'key': 'hygiene',
      'label': 'Hygiene Kit',
      'icon': Icons.sanitizer_outlined
    },
  ];

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
        _category = _categoryMap[_selectedItems.first] ?? 'OTHER';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      _showError('Select at least one item needed');
      return;
    }
    if (_requestLocation == null) {
      _showError('Please select your location on the map');
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.dio.post('/aid-requests', data: {
        'campaign_id': widget.campaignId,
        'category': _category,
        'items_needed': _selectedItems,
        'description': _descController.text.trim(),
        'urgency': _urgency,
        'family_size': int.parse(_familySizeController.text),
        'location': _requestAddress,
        'latitude': _requestLocation!.latitude,
        'longitude': _requestLocation!.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber[700]!;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Aid'),
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campaign Info Card
            Card(
              elevation: 0,
              color: cs.secondaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.campaign,
                        color: cs.onSecondaryContainer, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.campaignId == null
                                ? 'General Request'
                                : 'Campaign Request',
                            style: tt.labelMedium?.copyWith(
                                color: cs.onSecondaryContainer
                                    .withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.campaignTitle,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Items Section
            Text(
              'What do you need?',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select all that apply',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _itemOptions.map((item) {
                final selected = _selectedItems.contains(item['key']);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'], size: 18),
                      const SizedBox(width: 6),
                      Text(item['label']),
                    ],
                  ),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedItems.add(item['key']);
                      } else {
                        _selectedItems.remove(item['key']);
                      }
                      _updateCategory();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Category: $_category',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Description
            TextFormField(
              controller: _descController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Describe your situation *',
                hintText:
                    'Explain why you need aid and any special requirements...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 4,
              maxLength: 500,
              validator: (v) => v!.trim().length < 10
                  ? 'Please describe in at least 10 characters'
                  : null,
            ),
            const SizedBox(height: 16),

            // Urgency + Family Size
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField(
                    value: _urgency,
                    decoration: InputDecoration(
                      labelText: 'Urgency *',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber,
                          color: _urgencyColor(_urgency)),
                    ),
                    items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _urgencyColor(u),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(u),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _urgency = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _familySizeController,
                    decoration: const InputDecoration(
                      labelText: 'Family Size *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
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
            const SizedBox(height: 24),

            // Location Picker
            Text(
              'Your Location *',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the map to mark where you need aid delivered',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            LocationPicker(
              onLocationPicked: (latLng, address) {
                setState(() {
                  _requestLocation = latLng;
                  _requestAddress = address;
                });
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_loading ? 'Submitting...' : 'Submit Request'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your request will be reviewed by volunteers and the NGO',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
