import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';

class AdminDeliveryProofsScreen extends StatefulWidget {
  const AdminDeliveryProofsScreen({super.key});
  @override
  State<AdminDeliveryProofsScreen> createState() => _AdminDeliveryProofsScreenState();
}

class _AdminDeliveryProofsScreenState extends State<AdminDeliveryProofsScreen> {
  List _deliveries = [];
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    try {
      final res = await _api.dio.get('/admin/aids/delivered');
      setState(() {
        _deliveries = res.data['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _deliveries.length,
        itemBuilder: (context, i) {
          final d = _deliveries[i];
          return Card(
            child: ListTile(
              leading: d['delivery_proof_url']!= null
              ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(d['delivery_proof_url'], width: 60, height: 60, fit: BoxFit.cover),
                  )
                : const Icon(Icons.image_not_supported),
              title: Text('${d['org_name']} → ${d['victim_name']}'),
              subtitle: Text('Delivered: ${d['delivered_at']?.toString().split('T')[0]?? ''}\nBy: ${d['delivered_by_name']}'),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  if (d['delivery_proof_url']!= null) {
                    await launchUrl(Uri.parse(d['delivery_proof_url']));
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}