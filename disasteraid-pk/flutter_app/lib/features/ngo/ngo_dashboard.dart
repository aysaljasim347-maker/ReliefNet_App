import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaigns/screens/campaign_create_screen.dart';
import '../../campaigns/screens/campaign_list_screen.dart';
import '../../campaigns/providers/campaign_provider.dart';

class NgoDashboard extends ConsumerWidget {
  const NgoDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCampaigns = ref.watch(myCampaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
              );
              if (created == true) ref.invalidate(myCampaignsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myCampaignsProvider),
        child: myCampaigns.when(
          data: (list) => list.isEmpty
            ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No campaigns yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Campaign'),
                        onPressed: () async {
                          final created = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CampaignCreateScreen()),
                          );
                          if (created == true) ref.invalidate(myCampaignsProvider);
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final progress = c.raisedAmount / c.targetAmount;
                    return Card(
                      child: ListTile(
                        title: Text(c.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${c.status}'),
                            LinearProgressIndicator(value: progress.clamp(0, 1)),
                            Text('Rs ${c.raisedAmount.toInt()} / ${c.targetAmount.toInt()}'),
                          ],
                        ),
                        trailing: Chip(label: Text(c.category)),
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CampaignListScreen()),
        ),
        icon: const Icon(Icons.public),
        label: const Text('View All'),
      ),
    );
  }
}
