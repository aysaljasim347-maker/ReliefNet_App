import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});
  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List _withdrawals = [];
  bool _loading = true;
  String _filter = 'PENDING';
  String? _error;
  final _api = ApiClient();
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = _filter == 'ALL'? <String, dynamic>{} : {'status': _filter};
      final res = await _api.dio.get('/admin/withdrawals', queryParameters: params);
      if (mounted) {
        setState(() { 
          _withdrawals = SafeDataHandler.extractList(res.data); 
          _loading = false; 
        }); // ApiClient unwraps
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load withdrawals'; _loading = false; });
    }
  }

  Future<void> _approveWithdrawal(int id) async {
    final notes = await _showApproveDialog();
    if (notes == null || !mounted) return;
    await _submitStatus(id, 'APPROVED', adminNotes: notes);
  }

  Future<String?> _showApproveDialog() async {
    final ctrl = TextEditingController();
    if (!mounted || !context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This marks the request as approved. You still need to transfer money and upload proof to complete.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Approve')),
        ],
      ),
    );
  }

  Future<void> _completeWithdrawal(int id, double amount) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img == null || !mounted || !context.mounted) return;

    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Confirm you transferred ${_currency.format(amount)} to the NGO bank account.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Transaction Ref / Notes *',
                hintText: 'Bank transfer ID',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete')),
        ],
      ),
    );
    if (confirmed != true || notesCtrl.text.trim().isEmpty) {
      if (mounted && context.mounted && notesCtrl.text.trim().isEmpty) {
        _showError('Transaction reference required');
      }
      return;
    }
    if (!mounted) return;
    await _submitStatus(id, 'COMPLETED', adminNotes: notesCtrl.text.trim(), proofFile: img);
  }

  Future<void> _rejectWithdrawal(int id) async {
    final reason = await _showRejectDialog();
    if (reason == null || !mounted) return;
    await _submitStatus(id, 'REJECTED', rejectionReason: reason);
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    if (!mounted || !context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Invalid bank details, insufficient docs...',
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

  Future<void> _submitStatus(int id, String status, {String? adminNotes, String? rejectionReason, XFile? proofFile}) async {
    try {
      FormData formData;
      if (proofFile!= null) {
        formData = FormData.fromMap({
          'status': status,
          'admin_notes': adminNotes,
          'proof': await MultipartFile.fromFile(proofFile.path),
        });
      } else {
        formData = FormData.fromMap({
          'status': status,
          if (adminNotes!= null) 'admin_notes': adminNotes,
          if (rejectionReason!= null) 'rejection_reason': rejectionReason,
        });
      }

      await _api.dio.patch('/admin/withdrawals/$id', data: formData);
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal ${status.toLowerCase()}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadWithdrawals();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _showError(String msg) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDoc(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showError('Could not open document');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED': return Colors.green;
      case 'APPROVED': return Colors.blue;
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
            children: ['ALL', 'PENDING', 'APPROVED', 'COMPLETED', 'REJECTED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) { setState(() => _filter = f); _loadWithdrawals(); },
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
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadWithdrawals);
    if (_withdrawals.isEmpty) return _buildEmptyState(cs, tt);
    return _buildWithdrawalList(cs, tt);
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 140,
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
      icon: Icons.account_balance_wallet_outlined,
      title: 'No $_filter withdrawals',
      subtitle: _filter == 'PENDING'
   ? 'Withdrawal requests from NGOs will appear here'
        : 'No withdrawals found with this status',
    );
  }

  Widget _buildWithdrawalList(ColorScheme cs, TextTheme tt) {
    return RefreshIndicator(
      onRefresh: _loadWithdrawals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        itemBuilder: (context, i) {
          final w = _withdrawals[i];
          final amount = _parseAmount(w['amount']);
          final status = w['status']?? 'PENDING';
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
                    child: Icon(Icons.account_balance_wallet_outlined, color: statusColor, size: 22),
                  ),
                  title: Text(
                    '${_currency.format(amount)} - ${w['org_name']}',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${w['bank_name']} | ${_formatDate(w['requested_at'])}',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Bank Details
                          _detailRow(Icons.person_outline, 'Account Title', w['account_title'], cs, tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.numbers_outlined, 'Account Number', w['account_number'], cs, tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.credit_card_outlined, 'IBAN', w['iban'], cs, tt),
                          const SizedBox(height: 12),
                          _detailRow(Icons.email_outlined, 'Requester', w['requester_email'], cs, tt),

                          // Admin Notes
                          if (w['admin_notes']!= null)...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notes_outlined, size: 16, color: Colors.blue[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Admin Notes',
                                        style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(w['admin_notes'], style: tt.bodyMedium),
                                ],
                              ),
                            ),
                          ],

                          // Rejection Reason
                          if (w['rejection_reason']!= null)...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rejection Reason',
                                        style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(w['rejection_reason'], style: tt.bodyMedium),
                                ],
                              ),
                            ),
                          ],

                          // Transfer Proof
                          if (w['transfer_proof_url']!= null)...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openDoc(w['transfer_proof_url']),
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('View Transfer Proof'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],

                          // Processed Date
                          if (w['processed_at']!= null)...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Processed: ${_formatDate(w['processed_at'])}',
                                  style: tt.bodySmall?.copyWith(color: Colors.green[700]),
                                ),
                              ],
                            ),
                          ],

                          // Actions
                          const SizedBox(height: 16),
                          if (w['status'] == 'PENDING')
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectWithdrawal(w['id']),
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
                                    onPressed: () => _approveWithdrawal(w['id']),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (w['status'] == 'APPROVED')
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _completeWithdrawal(w['id'], amount),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Upload Proof & Complete'),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
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

  Widget _detailRow(IconData icon, String label, String? value, ColorScheme cs, TextTheme tt) {
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

  double _parseAmount(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString())?? 0;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return date.toString().split('T')[0];
    }
  }
}