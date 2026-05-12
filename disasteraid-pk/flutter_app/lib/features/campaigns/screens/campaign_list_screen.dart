import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/campaign.dart';
import '../services/campaign_service.dart';
import '../../../shared/widgets/report_dialog.dart';
import 'campaign_detail_screen.dart';

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});
  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  final _service = CampaignService();
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  final List<Campaign> _campaigns = [];
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  String? _selectedCategory;
  String _sort = 'funded';
  String _query = '';
  String _location = '';
  bool _showFilters = false; // collapsible filter panel

  final List<Map<String, dynamic>> _categories = const [
    {'key': null, 'label': 'All', 'icon': Icons.apps},
    {'key': 'FOOD', 'label': 'Food', 'icon': Icons.restaurant},
    {'key': 'MEDICAL', 'label': 'Medical', 'icon': Icons.medical_services},
    {'key': 'SHELTER', 'label': 'Shelter', 'icon': Icons.home_outlined},
    {'key': 'EDUCATION', 'label': 'Education', 'icon': Icons.school_outlined},
    {'key': 'CLOTHING', 'label': 'Clothing', 'icon': Icons.checkroom},
    {'key': 'OTHER', 'label': 'Other', 'icon': Icons.category_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _locationController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _location = _locationController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.getAllCampaigns(category: _selectedCategory);
      if (!mounted) return;
      setState(() {
        _campaigns
          ..clear()
          ..addAll(list);
        _loading = false;
      });
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
          _error = ApiClient.messageFromError(e, 'Failed to load campaigns');
          _loading = false;
        });
      }
    }
  }

  List<Campaign> get _visibleCampaigns {
    final filtered = _campaigns.where((campaign) {
      final haystack = [
        campaign.title,
        campaign.description,
        campaign.orgName ?? '',
        campaign.category,
      ].join(' ').toLowerCase();
      final location = (campaign.location ?? '').toLowerCase();
      return (_query.isEmpty || haystack.contains(_query)) &&
          (_location.isEmpty || location.contains(_location));
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'ending':
          final aDate = a.endDate ?? DateTime(2999);
          final bDate = b.endDate ?? DateTime(2999);
          return aDate.compareTo(bDate);
        case 'newest':
          return b.createdAt.compareTo(a.createdAt);
        case 'funded':
        default:
          return b.percentRaised.compareTo(a.percentRaised);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildFilters(tt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(TextTheme tt) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar – always visible
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search campaigns',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? IconButton(
                      tooltip: 'Toggle filters',
                      icon: Icon(
                        _showFilters ? Icons.filter_list_off : Icons.filter_list,
                        color: _showFilters ? cs.primary : null,
                      ),
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                    )
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: _searchController.clear,
                    ),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        // Collapsible extra filters
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _showFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 8),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Filter by city or province',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: _location.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear location',
                            icon: const Icon(Icons.close),
                            onPressed: _locationController.clear,
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _sort,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    prefixIcon: Icon(Icons.sort),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'funded', child: Text('% funded')),
                    DropdownMenuItem(value: 'ending', child: Text('Ending soon')),
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  ],
                  onChanged: (value) => setState(() => _sort = value ?? 'funded'),
                ),
                const SizedBox(height: 10),
                Text('Category', style: tt.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categories.map((cat) {
                    final key = cat['key'] as String?;
                    final selected = _selectedCategory == key;
                    return FilterChip(
                      avatar: Icon(cat['icon'] as IconData, size: 16),
                      label: Text(cat['label'] as String),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedCategory = key);
                        _load();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return _CampaignListShimmer();
    if (_error != null) {
      return ListView(children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      ]);
    }
    final visible = _visibleCampaigns;
    if (visible.isEmpty) {
      return ListView(children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: EmptyState(
            icon: Icons.campaign_outlined,
            title: 'No campaigns yet',
            subtitle: 'Try a different search, category, or location',
            onAction: () {
              _searchController.clear();
              _locationController.clear();
              setState(() {
                _selectedCategory = null;
                _query = '';
                _location = '';
              });
              _load();
            },
            actionLabel: 'Reset filters',
          ),
        ),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: visible.length,
      itemBuilder: (context, i) => CampaignCard(campaign: visible[i]),
    );
  }
}

class _CampaignListShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: cs.surfaceContainerHighest,
          highlightColor: cs.surfaceContainerLow,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback? onTap;
  final bool showReport;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.onTap,
    this.showReport = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final daysText = campaign.daysLeft == null ? 'No end date' : '${campaign.daysLeft} days left';
    final statusColor = campaign.isOpenForDonations ? cs.primary : cs.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CampaignDetailScreen(id: campaign.id)),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: campaign.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: campaign.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                          errorWidget: (_, __, ___) => _ImageFallback(icon: Icons.image_not_supported_outlined),
                        )
                      : _ImageFallback(icon: Icons.campaign_outlined),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _Badge(
                    label: '${campaign.percentRaised}% funded',
                    foregroundColor: cs.onPrimaryContainer,
                    backgroundColor: cs.primaryContainer,
                  ),
                ),
                if (showReport)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      tooltip: 'Report campaign',
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => ReportDialog(
                          targetType: 'campaign',
                          targetId: campaign.id,
                          targetName: campaign.title,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Badge(
                        label: campaign.category,
                        foregroundColor: cs.onSecondaryContainer,
                        backgroundColor: cs.secondaryContainer,
                      ),
                      _Badge(
                        label: campaign.status,
                        foregroundColor: campaign.isOpenForDonations ? cs.onPrimaryContainer : cs.onErrorContainer,
                        backgroundColor: campaign.isOpenForDonations ? cs.primaryContainer : cs.errorContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campaign.title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    campaign.orgName ?? 'Verified NGO',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: campaign.progress,
                      backgroundColor: cs.surfaceContainerHighest,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppFormatters.pkrAmount(campaign.raisedAmount),
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'of ${NumberFormat.compact(locale: 'en_PK').format(campaign.targetAmount)}',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          campaign.location ?? 'Pakistan',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule_outlined, size: 18, color: statusColor),
                      const SizedBox(width: 4),
                      Text(daysText, style: tt.bodySmall?.copyWith(color: statusColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _Badge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final IconData icon;
  const _ImageFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: cs.onSurfaceVariant, size: 48)),
    );
  }
}
