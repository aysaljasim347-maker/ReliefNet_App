import 'dart:io';
import 'package:disasteraid_pk/features/campaigns/services/campaign_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/widgets/location_picker.dart';

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

  // ADDED: Location fields
  LatLng? _campaignLocation;
  String _campaignAddress = '';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked!= null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date!= null) setState(() => _endDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select campaign end date')));
      return;
    }
    if (_campaignLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select campaign location')));
      return;
    }
    setState(() => _loading = true);

    try {
      final formData = FormData.fromMap({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'target_amount': _target.text.trim(),
        'location': _campaignAddress, // Changed: use address from picker
        'end_date': _endDate!.toIso8601String(),
        'latitude': _campaignLocation!.latitude, // ADDED
        'longitude': _campaignLocation!.longitude, // ADDED
        'address': _campaignAddress.isEmpty? null : _campaignAddress, // ADDED
        if (_imageFile!= null)
          'image': await MultipartFile.fromFile(
            _imageFile!.path,
            filename: _imageFile!.path.split('/').last,
          ),
      });

      await CampaignService().createCampaign(formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign created successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Failed to create campaign';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Campaign')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _imageFile == null
                   ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('Tap to add campaign image', style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v!.trim().length < 5? 'Min 5 characters' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
              validator: (v) => v!.trim().length < 20? 'Min 20 chars' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField(
              value: _category,
              items: ['FOOD', 'MEDICAL', 'SHELTER', 'EDUCATION', 'CLOTHING', 'OTHER']
                 .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                 .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _target,
              decoration: InputDecoration(
                labelText: 'Target Amount (PKR)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v!.isEmpty) return 'Required';
                final amount = double.tryParse(v);
                if (amount == null || amount < 1000) return 'Min PKR 1,000';
                return null;
              },
            ),
            // REMOVED: Old TextFormField for location
            // ADDED: LocationPicker widget
            const SizedBox(height: 16),
            Text('Campaign Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LocationPicker(
              onLocationPicked: (latLng, address) {
                setState(() {
                  _campaignLocation = latLng;
                  _campaignAddress = address;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[400]!),
              ),
              title: Text(_endDate == null? 'Select End Date *' : 'Ends: ${_endDate!.toLocal().toString().split(' ')[0]}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _loading
                 ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Campaign', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}