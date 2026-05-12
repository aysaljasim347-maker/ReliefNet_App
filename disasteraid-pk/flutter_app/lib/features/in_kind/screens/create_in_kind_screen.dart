import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../services/in_kind_service.dart';

class CreateInKindScreen extends StatefulWidget {
  const CreateInKindScreen({super.key});

  @override
  State<CreateInKindScreen> createState() => _CreateInKindScreenState();
}

class _CreateInKindScreenState extends State<CreateInKindScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // Cross-platform image (web + Android)
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _uploadingImage = false;
  String? _cloudinaryUrl;

  DateTime? _expiresAt;

  final _picker = ImagePicker();
  final _service = InKindService();

  static const _cloudName = 'dbtwmioov';
  static const _uploadPreset = 'reliefnet_unsigned';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Pick image from gallery ───────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageFile = picked;
      _imageBytes = bytes;
      _cloudinaryUrl = null;
    });

    await _uploadToCloudinary(picked, bytes);
  }

  // ── Upload to Cloudinary ──────────────────────────────────────────────────
  Future<void> _uploadToCloudinary(XFile file, Uint8List bytes) async {
    setState(() => _uploadingImage = true);
    try {
      final dio = Dio();
      final filename = file.name.isNotEmpty ? file.name : 'image.jpg';

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'upload_preset': _uploadPreset,
        'folder': 'reliefnet/in_kind',
      });

      final res = await dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
      );

      if (mounted) {
        setState(() {
          _cloudinaryUrl = res.data['secure_url'] as String?;
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageFile = null;
          _imageBytes = null;
          _cloudinaryUrl = null;
          _uploadingImage = false;
        });
        _showError('Image upload failed. Please try again.');
      }
    }
  }

  // ── Pick expiry date ──────────────────────────────────────────────────────
  Future<void> _pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _expiresAt = date);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null || _cloudinaryUrl == null) {
      _showError('Please add a photo of the item');
      return;
    }
    if (_uploadingImage) {
      _showError('Please wait for the image to finish uploading');
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.createDonation(
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        imageUrl: _cloudinaryUrl!,
        location: _locationCtrl.text.trim(),
        latitude: null,
        longitude: null,
        expiresAt: _expiresAt?.toIso8601String(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(ApiClient.messageFromError(e, 'Failed to post donation'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donate an Item'),
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Image Picker ─────────────────────────────────
            GestureDetector(
              onTap: _uploadingImage ? null : _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _imageBytes != null && _cloudinaryUrl != null
                        ? Colors.green
                        : cs.outlineVariant,
                    width:
                        _imageBytes != null && _cloudinaryUrl != null ? 2 : 1,
                  ),
                ),
                child: _buildImageArea(cs, tt),
              ),
            ),
            const SizedBox(height: 24),

            // ── Item Name ────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g. Winter clothes, Rice bags, Blankets',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Minimum 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Condition, quantity, any notes...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 56),
                  child: Icon(Icons.notes_outlined),
                ),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // ── Pickup Location (manual text) ─────────────────
            TextFormField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Pickup Location *',
                hintText: 'e.g. House 12, Street 4, Lahore',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
                helperText: 'Enter the address where item can be collected',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Please enter a valid address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Expiry Date ──────────────────────────────────
            OutlinedButton.icon(
              onPressed: _pickExpiryDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _expiresAt == null
                    ? 'Set Expiry Date (optional)'
                    : 'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            if (_expiresAt != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expiresAt = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Remove expiry'),
                  style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Submit ───────────────────────────────────────
            FilledButton(
              onPressed: (_loading || _uploadingImage) ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post Donation', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image area ────────────────────────────────────────────────────────────
  Widget _buildImageArea(ColorScheme cs, TextTheme tt) {
    if (_uploadingImage) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Uploading image...',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      );
    }

    if (_imageBytes != null && _cloudinaryUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Uploaded',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() {
                  _imageFile = null;
                  _imageBytes = null;
                  _cloudinaryUrl = null;
                }),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 48, color: cs.onSurfaceVariant),
        const SizedBox(height: 12),
        Text('Add Item Photo *',
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Tap to upload from gallery',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
