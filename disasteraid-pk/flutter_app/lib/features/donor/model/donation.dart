import '../../../core/utils/app_formatters.dart';

class Donation {
  final int id;
  final int amount;
  final String status;
  final String campaignTitle;
  final String orgName;
  final int? campaignId;
  final String? campaignImageUrl;
  final String? campaignStatus;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? receiptUrl;
  final String? paymentMethod;
  final String? rejectionReason;

  Donation.fromJson(Map<String, dynamic> json)
      : id = _intValue(json['id']),
        amount = AppFormatters.pkrInt(json['amount']),
        status = json['status']?.toString() ?? 'PENDING',
        campaignTitle = json['campaign_title']?.toString() ?? 'Unknown Campaign',
        orgName = json['org_name']?.toString() ?? 'NGO',
        campaignId = json['campaign_id'] == null ? null : _intValue(json['campaign_id']),
        campaignImageUrl = _nullableString(json['image_url']),
        campaignStatus = _nullableString(json['campaign_status']),
        createdAt = AppFormatters.parseDate(json['created_at']),
        verifiedAt = AppFormatters.tryParseDate(json['verified_at']),
        receiptUrl = _nullableString(json['receipt_url']),
        paymentMethod = _nullableString(json['payment_method']),
        rejectionReason = _nullableString(json['rejection_reason']);
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
