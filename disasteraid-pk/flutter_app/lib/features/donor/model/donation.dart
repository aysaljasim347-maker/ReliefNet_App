class Donation {
  final int id;
  final double amount;
  final String status;
  final String campaignTitle;
  final String orgName;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? receiptUrl; // ADD THIS

  Donation.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        amount = double.parse(json['amount'].toString()),
        status = json['status'],
        campaignTitle = json['campaign_title'],
        orgName = json['org_name'],
        createdAt = DateTime.parse(json['created_at']),
        verifiedAt = json['verified_at']!= null? DateTime.parse(json['verified_at']) : null,
        receiptUrl = json['receipt_url']; // ADD THIS
}