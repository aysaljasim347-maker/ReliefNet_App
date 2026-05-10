import '../../../core/utils/app_formatters.dart';

class Withdrawal {
  final int id;
  final int amount;
  final String status;
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String iban;
  final String? adminNotes;
  final String? rejectionReason;
  final String? transferProofUrl;
  final DateTime requestedAt;
  final DateTime? processedAt;

  Withdrawal.fromJson(Map<String, dynamic> json)
      : id = _intValue(json['id']),
        amount = AppFormatters.pkrInt(json['amount']),
        status = json['status']?.toString() ?? 'PENDING',
        bankName = json['bank_name']?.toString() ?? 'Bank',
        accountTitle = json['account_title']?.toString() ?? 'Account',
        accountNumber = json['account_number']?.toString() ?? 'N/A',
        iban = json['iban']?.toString() ?? 'N/A',
        adminNotes = _nullableString(json['admin_notes']),
        rejectionReason = _nullableString(json['rejection_reason']),
        transferProofUrl = _nullableString(json['transfer_proof_url']),
        requestedAt = AppFormatters.parseDate(json['requested_at']),
        processedAt = AppFormatters.tryParseDate(json['processed_at']);
}

int _intValue(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? 0;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
