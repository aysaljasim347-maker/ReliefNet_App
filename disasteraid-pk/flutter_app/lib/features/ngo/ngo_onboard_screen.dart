import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/storage.dart';

class NgoOnboardScreen extends StatefulWidget {
  const NgoOnboardScreen({super.key});
  @override
  State<NgoOnboardScreen> createState() => _NgoOnboardScreenState();
}

class _NgoOnboardScreenState extends State<NgoOnboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgName = TextEditingController();
  final _regNum = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _mission = TextEditingController();
  final _email = TextEditingController(); // ADDED
  final _phone = TextEditingController(); // ADDED
  List<PlatformFile> _docs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Pre-fill email/phone from user
  }

  Future<void> _loadUserData() async {
    final user = await Storage.getUser();
    if (user!= null) {
      _email.text = user['email']?? '';
      _phone.text = user['phone']?? '';
    }
  }

  Future<void> _pickDocs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf']
    );
    if (result!= null) setState(() => _docs = result.files);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _docs.isEmpty) {
      setState(() => _error = 'Fill all fields and upload at least 1 document');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiClient();
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('org_name', _orgName.text.trim()),
        MapEntry('registration_number', _regNum.text.trim()),
        MapEntry('address', _address.text.trim()),
        MapEntry('contact_person', _contact.text.trim()),
        MapEntry('mission', _mission.text.trim()),
        MapEntry('email', _email.text.trim()), // ADDED
        MapEntry('phone', _phone.text.trim()), // ADDED
      ]);

      for (var file in _docs) {
        formData.files.add(MapEntry(
          'docs',
          await MultipartFile.fromFile(file.path!, filename: file.name),
        ));
      }

      await api.dio.post('/ngos/onboard', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for approval'), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error']?? 'Submission failed';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NGO Verification')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text('Organization Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orgName,
              decoration: InputDecoration(labelText: 'Organization Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.length < 3? 'Min 3 characters' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regNum,
              decoration: InputDecoration(labelText: 'Registration Number *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.length < 5? 'Min 5 characters' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              decoration: InputDecoration(labelText: 'Office Address *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              maxLines: 2,
              validator: (v) => v!.length < 10? 'Min 10 characters' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contact,
              decoration: InputDecoration(labelText: 'Contact Person *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.length < 2? 'Required' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email, // ADDED
              decoration: InputDecoration(labelText: 'Official Email *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)? 'Invalid email' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone, // ADDED
              decoration: InputDecoration(labelText: 'Official Phone *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.phone,
              validator: (v) =>!RegExp(r'^[0-9]{11}$').hasMatch(v!)? '11 digits required' : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mission,
              decoration: InputDecoration(labelText: 'Mission Statement *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              maxLines: 3,
              validator: (v) => v!.length < 20? 'Min 20 characters' : null
            ),
            const SizedBox(height: 24),
            Text('Documents', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Upload registration certificate, NTN, etc', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDocs,
              icon: const Icon(Icons.upload_file),
              label: Text(_docs.isEmpty? 'Upload Documents' : '${_docs.length} files selected'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
            ),
            if (_docs.isNotEmpty)...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: _docs.map((f) => Chip(
                label: Text(f.name.length > 15? '${f.name.substring(0, 15)}...' : f.name),
                onDeleted: () => setState(() => _docs.remove(f))
              )).toList())
            ],
            if (_error!= null)...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: TextStyle(color: Colors.red[700]))
              )
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit for Approval', style: TextStyle(fontSize: 16))
            ),
          ],
          ),
        ),
      ),
    );
  }
}