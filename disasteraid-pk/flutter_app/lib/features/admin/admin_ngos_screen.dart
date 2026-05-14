import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminNgosScreen extends StatefulWidget {
  const AdminNgosScreen({super.key});
  @override
  State<AdminNgosScreen> createState() => _AdminNgosScreenState();
}

class _AdminNgosScreenState extends State<AdminNgosScreen> {
  List _ngos = [];
  bool _loading = true;
  String? _error;
  String _filter = 'PENDING';
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchNgos();
  }

  Future<void> _fetchNgos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get('/admin/ngos', queryParameters: {
        if (_filter!= 'ALL') 'status': _filter,
      });
      if (mounted) {
        setState(() { 
          _ngos = SafeDataHandler.extractList(res.data); 
          _loading = false; 
        }); // ApiClient unwraps
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load NGOs'; _loading = false; });
    }
  }

  Future<void> _approve(int id) async {
    try {
      await _api.dio.patch('/admin/ngos/$id/approve');
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NGO Approved'), backgroundColor: Colors.green),
      );
      _fetchNgos();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _reject(int id) async {
    final reason = await _showRejectDialog();
    if (reason == null || !mounted) return;

    try {
      await _api.dio.patch('/admin/ngos/$id/reject', data: {'reason': reason});
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NGO Rejected'), backgroundColor: Colors.orange),
      );
      _fetchNgos();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject NGO'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Missing documents, invalid info...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason required')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDoc(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showError('Could not open document');
    }
  }

  void _showError(String msg) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'PENDING': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _fetchNgos(); },
                ),
              )
            ).toList(),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildBody(cs, tt),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _fetchNgos);
    if (_ngos.isEmpty) return _buildEmptyState(cs, tt);
    return _buildNgoList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) {
    return EmptyState(
      icon: Icons.business_outlined,
      title: 'No $_filter NGOs',
      subtitle: _filter == 'PENDING'
     ? 'New NGO applications will appear here'
        : 'No NGOs found with this status',
    );
  }

  Widget _buildNgoList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _fetchNgos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ngos.length,
        itemBuilder: (context, i) {
          final ngo = _ngos[i];
          final docs = List<String>.from(ngo['docs_url']?? []);
          final status = ngo['status']?? 'PENDING';
          final statusColor = _statusColor(status);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Status Bar
                Container(height: 4, color: statusColor),
                ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Icon(Icons.business_outlined, color: statusColor),
                  ),
                  title: Text(
                    ngo['org_name']?? 'Unknown NGO',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Reg: ${ngo['registration_number']?? 'N/A'}',
                        style: tt.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: tt.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Info Rows
                          _infoRow(Icons.person_outline, 'Contact Person', ngo['contact_person'], cs, tt),
                          const SizedBox(height: 12),
                          _infoRow(Icons.email_outlined, 'Email', ngo['email'], cs, tt),
                          const SizedBox(height: 12),
                          _infoRow(Icons.phone_outlined, 'Phone', ngo['phone'], cs, tt),
                          const SizedBox(height: 16),

                          // Mission
                          Text(
                            'Mission',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ngo['mission']?? 'No mission provided',
                              style: tt.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Documents
                          if (docs.isNotEmpty)...[
                            Row(
                              children: [
                                Icon(Icons.attach_file, size: 20, color: cs.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  'Documents (${docs.length})',
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                         ...docs.map((url) => _buildDocItem(url, cs, tt)),
                          ],

                          // Actions
                          if (status == 'PENDING')...[
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _reject(ngo['id']),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _approve(ngo['id']),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocItem(String url, ColorScheme cs, TextTheme tt) {
    final isPdf = url.toLowerCase().contains('.pdf');
    final fileName = url.split('/').last;

    if (isPdf) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(
            fileName,
            style: tt.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openDoc(url),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _openDoc(url),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                  height: 160,
                  color: cs.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (c, u, e) => Container(
                  height: 160,
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.error_outline, color: cs.onSurfaceVariant),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value, ColorScheme cs, TextTheme tt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value?? 'N/A',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}