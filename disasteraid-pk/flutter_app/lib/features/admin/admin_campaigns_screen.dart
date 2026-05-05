import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});
  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  List _campaigns = [];
  bool _loading = true;
  String _filter = 'ALL';
  final _api = ApiClient();

  @override
  void initState() { super.initState(); _loadCampaigns(); }

  Future<void> _loadCampaigns() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> params = _filter == 'ALL'? {} : {'status': _filter};
      final res = await _api.dio.get('/admin/campaigns', queryParameters: params);
      setState(() { _campaigns = res.data['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _api.dio.patch('/admin/campaigns/$id/status', data: {'status': status});
      _loadCampaigns();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Campaign $status')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: ['ALL', 'ACTIVE', 'PAUSED', 'COMPLETED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _loadCampaigns(); },
                ),
              )
            ).toList(),
          ),
        ),
        Expanded(
          child: _loading? const Center(child: CircularProgressIndicator())
            : _campaigns.isEmpty? const Center(child: Text('No campaigns'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _campaigns.length,
                  itemBuilder: (context, i) {
                    final c = _campaigns[i];
                    final progress = c['target_amount'] > 0? (c['raised_amount']?? 0) / c['target_amount'] : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(c['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['org_name'], style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress.clamp(0, 1)),
                            Text('Rs ${c['raised_amount']?? 0} / ${c['target_amount']}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(c['status'], style: const TextStyle(fontSize: 11)),
                          backgroundColor: c['status'] == 'ACTIVE'? Colors.green[100]
                            : c['status'] == 'PAUSED'? Colors.orange[100] : Colors.grey[200],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NGO: ${c['org_name']} (${c['ngo_email']})', style: const TextStyle(fontSize: 13)),
                                Text('Category: ${c['category']}', style: const TextStyle(fontSize: 13)),
                                Text('Location: ${c['location']?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (c['status'] == 'ACTIVE')
                                      Expanded(child: OutlinedButton(onPressed: () => _updateStatus(c['id'], 'PAUSED'), child: const Text('Pause'))),
                                    if (c['status'] == 'PAUSED')
                                      Expanded(child: FilledButton(onPressed: () => _updateStatus(c['id'], 'ACTIVE'), child: const Text('Resume'))),
                                    const SizedBox(width: 8),
                                    Expanded(child: OutlinedButton(onPressed: () => _updateStatus(c['id'], 'COMPLETED'), child: const Text('Complete'))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
