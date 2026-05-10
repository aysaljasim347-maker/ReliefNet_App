import '../../../core/utils/app_formatters.dart';

class Campaign {
  final int id;
  final int ngoId;
  final String title;
  final String description;
  final String category;
  final int targetAmount;
  final int raisedAmount;
  final String? imageUrl;
  final String? location;
  final String status;
  final String? orgName;
  final DateTime createdAt;
  final DateTime? endDate;
  final int donorCount;
  
  // CHANGED: Platform bank details instead of NGO bank
  final String? platformBankName;
  final String? platformAccountTitle;
  final String? platformAccountNumber;
  final String? platformIban;

  Campaign({
    required this.id,
    required this.ngoId,
    required this.title,
    required this.description,
    required this.category,
    required this.targetAmount,
    required this.raisedAmount,
    this.imageUrl,
    this.location,
    required this.status,
    this.orgName,
    required this.createdAt,
    this.endDate,
    this.donorCount = 0,
    this.platformBankName,
    this.platformAccountTitle,
    this.platformAccountNumber,
    this.platformIban,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: _intValue(json['id']),
      ngoId: _intValue(json['ngo_id']),
      title: json['title']?.toString() ?? 'Untitled campaign',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      targetAmount: AppFormatters.pkrInt(json['target_amount']),
      raisedAmount: AppFormatters.pkrInt(json['raised_amount']),
      imageUrl: _nullableString(json['image_url']),
      location: _nullableString(json['location']),
      status: json['status']?.toString() ?? 'ACTIVE',
      orgName: _nullableString(json['org_name']),
      createdAt: AppFormatters.parseDate(json['created_at']),
      endDate: AppFormatters.tryParseDate(json['end_date']),
      donorCount: _intValue(json['donor_count']),
      // CHANGED
      platformBankName: _nullableString(json['platform_bank_name']),
      platformAccountTitle: _nullableString(json['platform_account_title']),
      platformAccountNumber: _nullableString(json['platform_account_number']),
      platformIban: _nullableString(json['platform_iban']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ngo_id': ngoId,
      'title': title,
      'description': description,
      'category': category,
      'target_amount': targetAmount,
      'raised_amount': raisedAmount,
      'image_url': imageUrl,
      'location': location,
      'status': status,
      'org_name': orgName,
      'created_at': createdAt.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'donor_count': donorCount,
      'platform_bank_name': platformBankName,
      'platform_account_title': platformAccountTitle,
      'platform_account_number': platformAccountNumber,
      'platform_iban': platformIban,
    };
  }

  double get progress => targetAmount > 0? (raisedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get percentRaised => (progress * 100).toInt();
  bool get isOpenForDonations =>
      status == 'ACTIVE' && (endDate == null || endDate!.isAfter(DateTime.now()));

  int? get daysLeft {
    if (endDate == null) return null;
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff < 0? 0 : diff;
  }
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
