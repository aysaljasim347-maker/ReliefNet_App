import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';

class AdminNgosScreen extends StatefulWidget {
  const AdminNgosScreen({super.key});
  @override
  State<AdminNgosScreen> createState() => _AdminNgosScreenState();
}

class _AdminNgosScreenState extends State<AdminNgosScreen> {
  List _ngos = [];
  bool _loading = true;
  String? _error;
  final _api = ApiClient();

  @override
  void initState() { super.initState(); _fetchNgos(); }

  Future<void> _fetchNgos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get('/admin/ngos/pending');
      setState(() { _ngos = res.data['data']; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; _loading = false; });
    }
  }

  Future<void> _approve(int id) async {
    try {
      await _api.dio.post('/admin/ngos/$id/approve');
      _fetchNgos();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NGO Approved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(int id) async {
    final reason = await _showRejectDialog();
    if (reason!= null) {
      try {
        await _api.dio.post('/admin/ngos/$id/reject', data: {'reason': reason});
        _fetchNgos();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NGO Rejected')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject NGO'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Reason for rejection')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Reject')),
        ],
      ),
    );
  }

  Future<void> _openDoc(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading? const Center(child: CircularProgressIndicator())
        : _error!= null? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), FilledButton(onPressed: _fetchNgos, child: const Text('Retry'))]))
          : _ngos.isEmpty? const Center(child: Text('No pending NGOs'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _ngos.length,
                itemBuilder: (context, i) {
                  final ngo = _ngos[i];
                  final docs = List<String>.from(ngo['docs_url']?? []);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(ngo['org_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Reg: ${ngo['registration_number']}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Contact: ${ngo['contact_person']}'),
                              Text('Email: ${ngo['email']}'),
                              Text('Phone: ${ngo['phone']}'),
                              const SizedBox(height: 8),
                              Text('Mission: ${ngo['mission']}'),
                              const SizedBox(height: 16),
                              Text('Documents (${docs.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                         ...docs.map((url) => url.toLowerCase().contains('.pdf')
                           ? ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                    title: Text(url.split('/').last, style: const TextStyle(fontSize: 12)),
                                    trailing: const Icon(Icons.open_in_new, size: 18),
                                    onTap: () => _openDoc(url),
                                    contentPadding: EdgeInsets.zero,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: InkWell(
                                      onTap: () => _openDoc(url),
                                      child: CachedNetworkImage(
                                        imageUrl: url,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(height: 120, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                                        errorWidget: (c, u, e) => Container(height: 120, color: Colors.grey[200], child: const Icon(Icons.error)),
                                      ),
                                    ),
                                  )),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(child: FilledButton(onPressed: () => _approve(ngo['id']), child: const Text('Approve'))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton(onPressed: () => _reject(ngo['id']), child: const Text('Reject'))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
