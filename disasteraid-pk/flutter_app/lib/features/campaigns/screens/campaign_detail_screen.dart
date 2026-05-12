import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/app_formatters.dart';
import '../services/campaign_service.dart';
import '../models/campaign.dart';
import '../../../shared/widgets/report_dialog.dart';
import '../../../core/permsisions/permission.dart';
class CampaignDetailScreen extends StatefulWidget {
  final int id;
  const CampaignDetailScreen({super.key, required this.id});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final _service = CampaignService();
  Campaign? campaign;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final c = await _service.getCampaign(widget.id);
      if (mounted) {
        setState(() {
          campaign = c;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ApiClient.messageFromError(e, 'Failed to load campaign');
          loading = false;
        });
      }
    }
  }

  void _showDonateDialog() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.credit_card, color: Theme.of(context).colorScheme.primary),
              title: const Text('Donate via Card / JazzCash'),
              subtitle: const Text('Instant payment - Coming Soon'),
              onTap: () {
                Navigator.pop(ctx);
                _showMockDonateSheet();
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary),
              title: const Text('Bank Transfer'),
              subtitle: const Text('Transfer + Upload Slip - Available Now'),
              trailing: const Chip(label: Text('ACTIVE'), visualDensity: VisualDensity.compact),
              onTap: () {
                Navigator.pop(ctx);
                _showManualDonateDialog(); // CHANGED
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMockDonateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DonateSheet(
        campaign: campaign!,
        onSuccess: () {
          _load();
          Navigator.pop(ctx);
        },
      ),
    );
  }
Future<void> _showManualDonateDialog() async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  XFile? proofFile;
  bool loading = false;
  String? amountError;
  String? proofError;

  // Check if platform bank details exist
  if (campaign!.platformBankName == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Platform bank details not configured')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Donate to Campaign'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer to DisasterAid PK account:', 
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBankRow('Bank', campaign!.platformBankName),
                    _buildBankRow('Title', campaign!.platformAccountTitle),
                    _buildBankRow('Account', campaign!.platformAccountNumber),
                    _buildBankRow('IBAN', campaign!.platformIban),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('After transfer, upload screenshot below', 
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Amount You Transferred *',
                  prefixText: 'PKR ',
                  border: const OutlineInputBorder(),
                  helperText: 'Enter exact amount sent',
                  errorText: amountError,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final amount = AppFormatters.pkrInt(value);
                  setState(() => amountError = amount == 0 || amount >= 100 ? null : 'Minimum PKR 100');
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  final source = await showModalBottomSheet<ImageSource>(
                    context: ctx,
                    showDragHandle: true,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera_outlined),
                            title: const Text('Camera'),
                            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text('Gallery'),
                            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (source != null) {
                    await requestPermissions();
                    final result = await ImagePicker().pickImage(
                      source: source,
                      imageQuality: 75,
                      maxWidth: 1920,
                    );
                    if (result != null) {
                      setState(() {
                        proofFile = result;
                        proofError = null;
                      });
                    }
                  }
                },
                icon: Icon(proofFile == null? Icons.upload_file : Icons.check_circle,
                  color: proofFile == null? null : Theme.of(context).colorScheme.primary),
                label: Text(proofFile == null? 'Upload Transfer Screenshot *' : 'Screenshot Selected'),
              ),
              if (proofError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(proofError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                ),
              if (proofFile!= null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'File: ${proofFile!.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Reference note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                maxLength: 200,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: loading
              ? null
              : () async {
                  final amount = AppFormatters.pkrInt(amountController.text);
                  if (amount < 100) {
                    setState(() => amountError = 'Minimum PKR 100');
                    return;
                  }
                  if (proofFile == null) {
                    setState(() => proofError = 'Upload proof required');
                    return;
                  }
                  setState(() => loading = true);
                  try {
                    final formData = FormData.fromMap({
                      'campaign_id': campaign!.id,
                      'amount': amount.toString(),
                      'donor_note': noteController.text.trim(),
                      'proof': await MultipartFile.fromFile(proofFile!.path),
                    });
                    await ApiClient().dio.post('/donations/manual', data: formData);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Donation submitted for verification'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                      _load();
                    }
                  } on DioException catch (e) {
                    if (context.mounted) {
                      final msg = ApiClient.messageFromError(e, 'Failed to submit donation');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  }
                  if (ctx.mounted) setState(() => loading = false);
                },
            child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit Donation'),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBankRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value?? 'Not available', style: const TextStyle(fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: !loading && campaign != null && campaign!.isOpenForDonations
        ? FloatingActionButton.extended(
              onPressed: _showDonateDialog,
              icon: const Icon(Icons.favorite),
              label: const Text('Donate Now'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (loading) return _buildShimmer();
    if (error!= null) return _buildError();
    if (campaign == null) return _buildNotFound();
    return _buildContent();
  }

  Widget _buildShimmer() {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(toolbarHeight: 0, pinned: true),
        SliverToBoxAdapter(
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              children: [
                Container(height: 240, color: Colors.white),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(height: 20, width: 200, color: Colors.white),
                      const SizedBox(height: 16),
                      Container(height: 100, color: Colors.white),
                      const SizedBox(height: 16),
                      Container(height: 200, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return const CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('Campaign not found')),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final c = campaign!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share campaign',
              onPressed: () {
                final text = '${c.title}\n${AppFormatters.pkrAmount(c.raisedAmount)} raised of ${AppFormatters.pkrAmount(c.targetAmount)}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Campaign details copied')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ReportDialog(
                  targetType: 'campaign',
                  targetId: c.id,
                  targetName: c.title,
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: c.imageUrl!= null
              ? CachedNetworkImage(
                    imageUrl: c.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.campaign, size: 80, color: cs.onSurfaceVariant),
                    ),
                  )
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.campaign, size: 80, color: cs.onSurfaceVariant),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category + Status
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(c.category),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.primaryContainer,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(c.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _statusColor(c.status)),
                      ),
                      child: Text(
                        c.status,
                        style: tt.labelSmall?.copyWith(
                          color: _statusColor(c.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.people_outline, size: 16),
                      label: Text('${c.donorCount} donors'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  c.title,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Org + Location
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(c.orgName?? 'Verified NGO', style: tt.bodyMedium),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(c.location?? 'Pakistan', style: tt.bodyMedium),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 330;
                          return Flex(
                            direction: stacked ? Axis.vertical : Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: stacked ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Raised', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.pkrAmount(c.raisedAmount),
                                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (stacked) const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  Text('Goal', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.pkrAmount(c.targetAmount),
                                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: c.progress,
                          minHeight: 10,
                          backgroundColor: cs.surface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${c.percentRaised}% funded • ${c.daysLeft?? '∞'} days left',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!c.isOpenForDonations) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c.status == 'COMPLETED' || c.daysLeft == 0
                          ? 'Campaign ended'
                          : 'Donations are paused',
                      style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Description
                Text(
                  'About this campaign',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  c.description,
                  style: tt.bodyLarge?.copyWith(height: 1.6),
                ),
                SizedBox(height: 100 + MediaQuery.of(context).padding.bottom), // Space for FAB + home indicator
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class DonateSheet extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onSuccess;

  const DonateSheet({super.key, required this.campaign, required this.onSuccess});

  @override
  State<DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<DonateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _paymentMethod = 'MOCK';
  bool _loading = false;
  bool _canSubmit = false;
  final _api = ApiClient();

  final List<int> _quickAmounts = [500, 1000, 5000];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCanSubmit);
    _nameController.addListener(_updateCanSubmit);
    _emailController.addListener(_updateCanSubmit);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCanSubmit);
    _nameController.removeListener(_updateCanSubmit);
    _emailController.removeListener(_updateCanSubmit);
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _updateCanSubmit() {
    final amount = AppFormatters.pkrInt(_amountController.text);
    final email = _emailController.text.trim();
    final emailOk = email.isEmpty || RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
    final next = amount >= 100 && _nameController.text.trim().isNotEmpty && emailOk;
    if (mounted && next != _canSubmit) setState(() => _canSubmit = next);
  }

  Future<void> _donate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await _api.dio.post('/donations', data: {
        'campaign_id': widget.campaign.id,
        'amount': AppFormatters.pkrInt(_amountController.text),
        'donor_name': _nameController.text.trim(),
        'donor_email': _emailController.text.trim().isEmpty? null : _emailController.text.trim(),
        'payment_method': _paymentMethod,
        'is_anonymous': false,
      });

      if (mounted) {
        final txnRef = res.data?['transaction_ref']?.toString();
        final refDisplay = txnRef != null && txnRef.length >= 8 ? txnRef.substring(0, 8) : (txnRef ?? 'OK');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation successful! Ref: $refDisplay...'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onSuccess();
      }
    } on DioException catch (e) {
      final msg = ApiClient.messageFromError(e, 'Donation failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 8,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Donate to ${widget.campaign.title}',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Quick amounts', style: tt.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _quickAmounts
                .map((amt) => ChoiceChip(
                        label: Text('PKR $amt'),
                        selected: _amountController.text == amt.toString(),
                        onSelected: (_) => setState(() => _amountController.text = amt.toString()),
                      ))
                .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (PKR)',
                prefixText: 'PKR ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final amt = AppFormatters.pkrInt(v);
                if (amt == 0) return 'Required';
                if (amt < 100) return 'Min PKR 100';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value)) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: ['MOCK', 'JAZZCASH', 'EASYPAISA', 'STRIPE']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading || !_canSubmit ? null : _donate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                  ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Donation', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
