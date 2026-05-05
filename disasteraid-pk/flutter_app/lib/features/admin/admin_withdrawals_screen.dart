import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});
  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List _withdrawals = [];
  bool _loading = true;
  String _filter = 'PENDING';
  final _api = ApiClient();

  @override
  void initState() { super.initState(); _loadWithdrawals(); }

  Future<void> _loadWithdrawals() async {
    setState(() => _loading = true);
    try {
      final params = _filter == 'ALL'? {} : {'status': _filter};
      final res = await _api.dio.get('/admin/withdrawals', queryParameters: params);
      setState(() { _withdrawals = res.data['data']; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _processWithdrawal(int id, String action) async {
    String? ref;
    String? reason;
    if (action == 'APPROVED') {
      ref = await showDialog<String>(
        context: context,
        builder: (context) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Transaction Reference'),
            content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Bank transfer ref')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Approve'))],
          );
        },
      );
      if (ref == null) return;
    } else {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Rejection Reason'),
            content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Reject'))],
          );
        },
      );
      if (reason == null) return;
    }

    try {
      await _api.dio.patch('/admin/withdrawals/$id', data: {'status': action, 'transaction_ref': ref, 'rejection_reason': reason});
      _loadWithdrawals();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal $action')));
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
            children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map((f) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(label: Text(f), selected: _filter == f, onSelected: (_) { setState(() => _filter = f); _loadWithdrawals(); }),
              )
            ).toList(),
          ),
        ),
        Expanded(
          child: _loading? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _withdrawals.length,
                itemBuilder: (context, i) {
                  final w = _withdrawals[i];
                  return Card(
                    child: ExpansionTile(
                      title: Text('Rs ${w['amount']} - ${w['org_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${w['bank_name']} | ${w['created_at'].toString().split('T')[0]}'),
                      trailing: Chip(label: Text(w['status'], style: const TextStyle(fontSize: 11))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account: ${w['account_title']}'),
                              Text('Number: ${w['account_number']}'),
                              if (w['iban']!= null) Text('IBAN: ${w['iban']}'),
                              if (w['transaction_ref']!= null) Text('Ref: ${w['transaction_ref']}'),
                              if (w['rejection_reason']!= null) Text('Reason: ${w['rejection_reason']}', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              if (w['status'] == 'PENDING') Row(
                                children: [
                                  Expanded(child: OutlinedButton(onPressed: () => _processWithdrawal(w['id'], 'REJECTED'), child: const Text('Reject'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: FilledButton(onPressed: () => _processWithdrawal(w['id'], 'APPROVED'), child: const Text('Approve'))),
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
