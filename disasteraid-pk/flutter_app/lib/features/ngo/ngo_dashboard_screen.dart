import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';

class NGODashboardScreen extends StatefulWidget {
  const NGODashboardScreen({super.key});
  @override
  State<NGODashboardScreen> createState() => _NGODashboardScreenState();
}

class _NGODashboardScreenState extends State<NGODashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<FlSpot> _chartData = [];
  List _recentDonations = [];
  bool _loading = true;
  final _api = ApiClient();
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.dio.get('/ngos/dashboard/stats'),
        _api.dio.get('/ngos/dashboard/chart?days=30'),
        _api.dio.get('/ngos/dashboard/recent'),
      ]);

      final chartRaw = results[1].data['data'] as List;
      final spots = <FlSpot>[];
      for (int i = 0; i < chartRaw.length; i++) {
        spots.add(FlSpot(i.toDouble(), double.parse(chartRaw[i]['amount'].toString())));
      }

      setState(() {
        _stats = results[0].data['data'];
        _chartData = spots;
        _recentDonations = results[2].data['data'];
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
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildKpiGrid(),
          const SizedBox(height: 24),
          _buildChart(),
          const SizedBox(height: 24),
          _buildRecentDonations(),
        ],
      ),
    );
  }
Widget _buildKpiGrid() {
  double parseAmount(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString())?? 0;
  }

  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.4,
    children: [
      _kpiCard('Total Raised', _currency.format(parseAmount(_stats['total_raised'])), Icons.payments, Colors.green),
      _kpiCard('Wallet Balance', _currency.format(parseAmount(_stats['wallet_balance'])), Icons.account_balance_wallet, Colors.blue),
      _kpiCard('Delivery Rate', '${_stats['delivery_rate']?? 0}%', Icons.local_shipping, Colors.orange),
      _kpiCard('Active Campaigns', '${_stats['active_campaigns']?? 0}', Icons.campaign, Colors.purple),
    ],
  );
}

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('No donations in last 30 days', style: TextStyle(color: Colors.grey[600]))),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Donations - Last 30 Days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _chartData,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDonations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Donations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_recentDonations.isEmpty)
              Text('No donations yet', style: TextStyle(color: Colors.grey[600]))
            else
             ..._recentDonations.map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(d['donor_name']?[0]?? 'A'),
                    ),
                    title: Text(d['donor_name']?? 'Anonymous'),
                    subtitle: Text(d['campaign_title']),
                    trailing: Text(_currency.format(double.parse(d['amount'].toString()))),
                  )),
          ],
        ),
      ),
    );
  }
}