import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

class DeliverAidScreen extends StatefulWidget {
  final int aidId;
  final String victimName;
  final String location;

  const DeliverAidScreen({
    super.key,
    required this.aidId,
    required this.victimName,
    required this.location,
  });

  @override
  State<DeliverAidScreen> createState() => _DeliverAidScreenState();
}

class _DeliverAidScreenState extends State<DeliverAidScreen> {
  File? _proofImage;
  final _notesController = TextEditingController();
  bool _submitting = false;
  final _api = ApiClient();
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (img!= null) setState(() => _proofImage = File(img.path));
  }

  Future<void> _submitDelivery() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery photo required')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final formData = FormData.fromMap({
        'proof': await MultipartFile.fromFile(_proofImage!.path),
        'notes': _notesController.text.trim(),
      });

      await _api.dio.patch('/api/aids/${widget.aidId}/deliver', data: formData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery confirmed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Failed to submit delivery';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Delivery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aid Request #${widget.aidId}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person, 'Recipient', widget.victimName),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on, 'Location', widget.location),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Delivery Proof Photo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Take a clear photo showing the aid delivered to the recipient',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _proofImage == null
                 ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Tap to add photo', style: TextStyle(color: Colors.grey[600])),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_proofImage!, fit: BoxFit.cover),
                    ),
              ),
            ),
            if (_proofImage!= null)...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _proofImage = null),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Remove Photo'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            Text('Delivery Notes (Optional)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'e.g., Delivered food package at 3 PM. Family was grateful.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _submitting? null : _submitDelivery,
                icon: _submitting
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle),
                label: Text(_submitting? 'Submitting...' : 'Confirm Delivery'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[700])),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}