import 'package:disasteraid_pk/features/ngo/ngo_onboard_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../shared/widgets/error_state.dart';

class NGODashboardScreen extends StatefulWidget {
  const NGODashboardScreen({super.key});
  @override
  State<NGODashboardScreen> createState() => _NGODashboardScreenState();
}

class _NGODashboardScreenState extends State<NGODashboardScreen> {
  Map<String, dynamic>? _ngoProfile; // ADDED: Check status first
  Map<String, dynamic> _stats = {};
  List<FlSpot> _chartData = [];
  List _recentDonations = [];
  bool _loading = true;
  String? _error;
  final _api = ApiClient();
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1. Check NGO profile + status FIRST
      final profileRes = await _api.dio.get('/ngos/me');
      _ngoProfile = profileRes.data;

      // If no profile, go to onboarding
      if (_ngoProfile == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NgoOnboardScreen()),
          );
        }
        return;
      }

      // If not approved, don't load dashboard data
      if (_ngoProfile!['status']!= 'APPROVED') {
        setState(() => _loading = false);
        return;
      }

      // 2. Load dashboard only if APPROVED
      final results = await Future.wait([
        _api.dio.get('/ngos/dashboard/stats'),
        _api.dio.get('/ngos/dashboard/chart?days=30'),
        _api.dio.get('/ngos/dashboard/recent'),
      ]);

      final chartRaw = results[1].data as List;
      final spots = <FlSpot>[];
      for (int i = 0; i < chartRaw.length; i++) {
        spots.add(FlSpot(i.toDouble(), double.parse(chartRaw[i]['amount'].toString())));
      }

      if (mounted) {
        setState(() {
          _stats = results[0].data;
          _chartData = spots;
          _recentDonations = results[2].data as List;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard';
          _loading = false;
        });
      }
    }
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString())?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildBody(cs, tt),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadData);

    // GATE: Check NGO status before showing dashboard
    if (_ngoProfile == null) {
      return const SizedBox(); // Will redirect in _loadData
    }

    final status = _ngoProfile!['status'];
    if (status == 'PENDING') return _buildPendingScreen(cs, tt);
    if (status == 'REJECTED') return _buildRejectedScreen(cs, tt);

    return _buildDashboard(cs, tt); // status == 'APPROVED'
  }

  Widget _buildPendingScreen(ColorScheme cs, TextTheme tt) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                'Verification Pending',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents are under review by admin. This usually takes 24-48 hours.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ngoProfile!['org_name'] ?? '',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(ColorScheme cs, TextTheme tt) {
    final reason = _ngoProfile!['rejection_reason'];
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Verification Rejected',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (reason != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: Colors.red[900]),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const NgoOnboardScreen()),
                ),
                child: const Text('Resubmit Documents'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(ColorScheme cs, TextTheme tt) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Overview', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildKpiGrid(cs, tt),
        const SizedBox(height: 24),
        _buildChart(cs, tt),
        const SizedBox(height: 24),
        _buildRecentDonations(cs, tt),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 24, width: 150, color: Colors.white),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: List.generate(4, (_) => Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                )),
              ),
              const SizedBox(height: 24),
              Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              const SizedBox(height: 24),
              Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(ColorScheme cs, TextTheme tt) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _KpiCard(
          title: 'Total Raised',
          value: _currency.format(_parseAmount(_stats['total_raised'])),
          icon: Icons.payments_outlined,
          color: Colors.green,
        ),
        _KpiCard(
          title: 'Wallet Balance',
          value: _currency.format(_parseAmount(_stats['wallet_balance'])),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.blue,
        ),
        _KpiCard(
          title: 'Delivery Rate',
          value: '${_stats['delivery_rate']?? 0}%',
          icon: Icons.local_shipping_outlined,
          color: Colors.orange,
        ),
        _KpiCard(
          title: 'Active Campaigns',
          value: '${_stats['active_campaigns']?? 0}',
          icon: Icons.campaign_outlined,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildChart(ColorScheme cs, TextTheme tt) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Donations',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Last 30 Days',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_chartData.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('No donations yet', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: cs.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _chartData,
                        isCurved: true,
                        color: cs.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: cs.primary.withOpacity(0.1),
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

  Widget _buildRecentDonations(ColorScheme cs, TextTheme tt) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Donations', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_recentDonations.isNotEmpty)
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentDonations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('No donations yet', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
           ..._recentDonations.take(5).map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Text(
                        d['donor_name']?[0].toUpperCase()?? 'A',
                        style: TextStyle(color: cs.onSecondaryContainer),
                      ),
                    ),
                    title: Text(
                      d['donor_name']?? 'Anonymous',
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      d['campaign_title']?? 'General Donation',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currency.format(_parseAmount(d['amount'])),
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM').format(DateTime.parse(d['created_at'])),
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Icon(Icons.arrow_outward, color: color.withOpacity(0.5), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}