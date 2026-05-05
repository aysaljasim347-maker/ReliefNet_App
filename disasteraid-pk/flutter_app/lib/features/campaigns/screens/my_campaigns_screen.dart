import 'package:flutter/material.dart';
import '../services/campaign_service.dart';
import '../models/campaign.dart';

class MyCampaignsScreen extends StatefulWidget {
  const MyCampaignsScreen({super.key});
  @override
  State<MyCampaignsScreen> createState() => _MyCampaignsScreenState();
}

class _MyCampaignsScreenState extends State<MyCampaignsScreen> {
  final _service = CampaignService();
  List<Campaign> _campaigns = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final list = await _service.getMyCampaigns();
      setState(() { _campaigns = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Campaigns')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
            ? const Center(child: Text('No campaigns yet'))
              : ListView.builder(
                  itemCount: _campaigns.length,
                  itemBuilder: (context, i) {
                    final c = _campaigns[i];
                    return ListTile(
                      title: Text(c.title),
                      subtitle: Text('Rs ${c.raisedAmount.toInt()} / ${c.targetAmount.toInt()}'),
                      trailing: Chip(label: Text(c.status)),
                    );
                  },
                ),
    );
  }
}
