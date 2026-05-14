import 'dart:io';
import 'package:disasteraid_pk/features/campaigns/services/campaign_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/api/api_client.dart';

class CampaignCreateScreen extends StatefulWidget {
  const CampaignCreateScreen({super.key});
  @override
  State<CampaignCreateScreen> createState() => _CampaignCreateScreenState();
}

class _CampaignCreateScreenState extends State<CampaignCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _target = TextEditingController();
  String _category = 'FOOD';
  File? _imageFile;
  DateTime? _endDate;
  bool _loading = false;
  final _picker = ImagePicker();

  LatLng? _campaignLocation;
  String _campaignAddress = '';

  final List<Map<String, dynamic>> _categories = [
    {'key': 'FOOD', 'label': 'Food', 'icon': Icons.restaurant},
    {'key': 'MEDICAL', 'label': 'Medical', 'icon': Icons.medical_services},
    {'key': 'SHELTER', 'label': 'Shelter', 'icon': Icons.home},
    {'key': 'EDUCATION', 'label': 'Education', 'icon': Icons.school},
    {'key': 'CLOTHING', 'label': 'Clothing', 'icon': Icons.checkroom},
    {'key': 'OTHER', 'label': 'Other', 'icon': Icons.category},
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null && mounted) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _endDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate == null) {
      _showError('Please select campaign end date');
      return;
    }
    if (_campaignLocation == null) {
      _showError('Please select campaign location');
      return;
    }
    setState(() => _loading = true);

    try {
      final formData = FormData.fromMap({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'target_amount': _target.text.trim(),
        'location': _campaignAddress,
        'end_date': _endDate!.toIso8601String(),
        'latitude': _campaignLocation!.latitude,
        'longitude': _campaignLocation!.longitude,
        'address': _campaignAddress.isEmpty? null : _campaignAddress,
        if (_imageFile != null)
          'image': await MultipartFile.fromFile(
            _imageFile!.path,
            filename: _imageFile!.path.split('/').last,
          ),
      });

      await CampaignService().createCampaign(formData);

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      final apiErr = e.error as ApiException?;
      final msg = apiErr?.message ?? 'Failed to create campaign';
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Campaign'),
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: _imageFile == null
                  ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: cs.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'Add Campaign Image',
                            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to upload',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() => _imageFile = null),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Campaign Title *',
                hintText: 'e.g. Flood Relief for Sindh',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().length < 5? 'Minimum 5 characters' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe the cause and how funds will be used',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 500,
              validator: (v) => v!.trim().length < 20? 'Minimum 20 characters' : null,
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField(
              value: _category,
              items: _categories
                .map((e) => DropdownMenuItem(
                        value: e['key'],
                        child: Row(
                          children: [
                            Icon(e['icon'], size: 20),
                            const SizedBox(width: 12),
                            Text(e['label']),
                          ],
                        ),
                      ))
                 .toList(),
              onChanged: (v) => setState(() => _category = v as String ),
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Target Amount
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Target Amount *',
                prefixText: 'PKR ',
                helperText: 'Minimum PKR 1,000',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                final amount = double.tryParse(v);
                if (amount == null || amount < 1000) return 'Minimum PKR 1,000';
                if (amount > 100000000) return 'Maximum PKR 100M';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Location Section
            Text(
              'Campaign Location *',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select where aid will be distributed',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            LocationPicker(
              onLocationPicked: (latLng, address) {
                setState(() {
                  _campaignLocation = latLng;
                  _campaignAddress = address;
                });
              },
            ),
            if (_campaignLocation!= null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _campaignAddress,
                        style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // End Date
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _endDate == null
                  ? 'Select End Date *'
                    : 'Ends: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
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
                  : const Text('Create Campaign', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
          ),
        ),
      ),
    );
  }
}