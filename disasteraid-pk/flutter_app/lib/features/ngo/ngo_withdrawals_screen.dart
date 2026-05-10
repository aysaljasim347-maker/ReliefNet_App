import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/app_formatters.dart';
import 'models/withdrawal.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';

class NgoWithdrawalsScreen extends StatefulWidget {
  const NgoWithdrawalsScreen({super.key});
  @override
  State<NgoWithdrawalsScreen> createState() => _NgoWithdrawalsScreenState();
}

class _NgoWithdrawalsScreenState extends State<NgoWithdrawalsScreen> {
  List<Withdrawal> _withdrawals = [];
  Map<String, dynamic>? _wallet;
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
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.dio.get('/ngos/wallet'),
        _api.dio.get('/ngos/withdrawals'),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0].data; // ApiClient unwraps
          _withdrawals = (results[1].data as List)
          .map((e) => Withdrawal.fromJson(e))
          .toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load data'; _loading = false; });
    }
  }

  Future<void> _showWithdrawDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _WithdrawDialog(balance: AppFormatters.pkrInt(_wallet?['balance'])),
    );
    if (result == true) _loadData();
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

  void _showWithdrawalDetails(Withdrawal w) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Withdrawal Details',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildDetailRow('Amount', _currency.format(w.amount)),
            _buildDetailRow('Status', w.status, color: _statusColor(w.status)),
            _buildDetailRow('Bank', w.bankName),
            _buildDetailRow('Account Title', w.accountTitle),
            _buildDetailRow('Account #', w.accountNumber),
            _buildDetailRow('IBAN', w.iban),
            _buildDetailRow('Requested', DateFormat('dd MMM yyyy, hh:mm a').format(w.requestedAt)),
            if (w.processedAt!= null)
              _buildDetailRow('Processed', DateFormat('dd MMM yyyy, hh:mm a').format(w.processedAt!)),
            if (w.adminNotes!= null)...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Notes',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(w.adminNotes!, style: tt.bodyMedium),
                  ],
                ),
              ),
            ],
            if (w.rejectionReason!= null)...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
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
                    Text(w.rejectionReason!, style: tt.bodyMedium),
                  ],
                ),
              ),
            ],
            if (w.transferProofUrl!= null)...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(w.transferProofUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View Transfer Proof'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildBody(cs, tt),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) return _buildShimmer();
    if (_error!= null) return ErrorState(message: _error!, onRetry: _loadData);

    final balance = AppFormatters.pkrInt(_wallet?['balance']);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primaryContainer, cs.primaryContainer.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: cs.onPrimaryContainer),
                  const SizedBox(height: 12),
                  Text(
                    'Available Balance',
                    style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currency.format(balance),
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: balance >= 100? _showWithdrawDialog : null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Request Withdrawal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  if (balance < 100)...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Minimum withdrawal: 100 PKR',
                          style: tt.bodySmall?.copyWith(color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // History Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Withdrawal History',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_withdrawals.length} total',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Withdrawals List
          if (_withdrawals.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No withdrawals yet',
              subtitle: 'Request your first withdrawal when balance reaches 100 PKR',
            )
          else
        ..._withdrawals.map((w) => _WithdrawalCard(
              withdrawal: w,
              statusColor: _statusColor(w.status),
              currency: _currency,
              onTap: () => _showWithdrawalDetails(w),
            )),
        ],
      ),
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
            children: [
              Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 24),
            ...List.generate(3, (_) => Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final Withdrawal withdrawal;
  final Color statusColor;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _WithdrawalCard({
    required this.withdrawal,
    required this.statusColor,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_outlined, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(withdrawal.amount),
                          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${withdrawal.bankName} • ${withdrawal.accountNumber}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          withdrawal.status,
                          style: tt.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(withdrawal.requestedAt),
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              if (withdrawal.status == 'REJECTED' && withdrawal.rejectionReason!= null)...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        withdrawal.rejectionReason!,
                        style: tt.bodySmall?.copyWith(color: Colors.red[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (withdrawal.status == 'APPROVED')...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.pending_outlined, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Awaiting transfer from admin',
                      style: tt.bodySmall?.copyWith(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  final int balance;
  const _WithdrawDialog({required this.balance});

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  final _titleController = TextEditingController();
  final _accountController = TextEditingController();
  final _ibanController = TextEditingController();
  bool _submitting = false;
  bool _loadingBank = true;
  final _api = ApiClient();
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _titleController.dispose();
    _accountController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    try {
      final res = await _api.dio.get('/ngos/profile');
      final profile = res.data; // ApiClient unwraps
      if (mounted) {
        setState(() {
          _bankController.text = profile['bank_name']?? '';
          _titleController.text = profile['bank_account_title']?? '';
          _accountController.text = profile['bank_account_number']?? '';
          _ibanController.text = profile['bank_iban']?? '';
          _loadingBank = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBank = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await _api.dio.post('/ngos/withdrawals', data: {
        'amount': AppFormatters.pkrInt(_amountController.text),
        'bank_name': _bankController.text.trim(),
        'account_title': _titleController.text.trim(),
        'account_number': _accountController.text.trim(),
        'iban': _ibanController.text.trim().toUpperCase(),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Request Withdrawal'),
      content: _loadingBank
      ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Available Balance', style: tt.bodyMedium),
                        Text(
                          _currency.format(widget.balance),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR) *',
                      prefixText: 'PKR ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final amt = AppFormatters.pkrInt(v);
                      if (amt < 100) return 'Minimum 100 PKR';
                      if (amt > widget.balance) return 'Insufficient balance';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bank Details',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                    validator: (v) => v!.trim().length < 3? 'Min 3 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Account Title *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v!.trim().length < 3? 'Min 3 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.trim().length < 8? 'Min 8 digits' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ibanController,
                    decoration: const InputDecoration(
                      labelText: 'IBAN (24 chars) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card_outlined),
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 24,
                    validator: (v) {
                      if (v!.trim().length!= 24) return 'IBAN must be 24 characters';
                      if (!v.startsWith('PK')) return 'IBAN must start with PK';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
      actions: [
        TextButton(
          onPressed: _submitting? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting? null : _submit,
          child: _submitting
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Submit'),
        ),
      ],
    );
  }
}
