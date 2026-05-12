class InKindDonation {
  final int id;
  final int donorId;
  final String donorName;
  final String title;
  final String? description;
  final String? imageUrl;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime? expiresAt;
  final String status; // available | claimed | expired
  final int? claimedBy;
  final String? claimedByName;
  final String? claimedByEmail;
  final int pendingRequests; // only present on donor's /my list
  final int totalRequests; // only present on admin/detail views
  final _MyRequest? myRequest; // only present on detail view for beneficiary
  final DateTime createdAt;

  InKindDonation({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.title,
    this.description,
    this.imageUrl,
    required this.location,
    this.latitude,
    this.longitude,
    this.expiresAt,
    required this.status,
    this.claimedBy,
    this.claimedByName,
    this.claimedByEmail,
    this.pendingRequests = 0,
    this.totalRequests = 0,
    this.myRequest,
    required this.createdAt,
  });

  factory InKindDonation.fromJson(Map<String, dynamic> j) => InKindDonation(
        id: _intVal(j['id']),
        donorId: _intVal(j['donor_id']),
        donorName: j['donor_name']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: _nullStr(j['description']),
        imageUrl: _nullStr(j['image_url']),
        location: j['location']?.toString() ?? '',
        latitude: j['latitude'] != null
            ? double.tryParse(j['latitude'].toString())
            : null,
        longitude: j['longitude'] != null
            ? double.tryParse(j['longitude'].toString())
            : null,
        expiresAt:
            j['expires_at'] != null ? DateTime.tryParse(j['expires_at']) : null,
        status: j['status']?.toString() ?? 'available',
        claimedBy: j['claimed_by'] != null ? _intVal(j['claimed_by']) : null,
        claimedByName: _nullStr(j['claimed_by_name']),
        claimedByEmail: _nullStr(j['claimed_by_email']),
        pendingRequests: _intVal(j['pending_requests']),
        totalRequests: _intVal(j['total_requests']),
        myRequest: j['my_request'] != null && j['my_request'] is Map
            ? _MyRequest.fromJson(
                Map<String, dynamic>.from(j['my_request'] as Map))
            : null,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  bool get isAvailable => status == 'available';
  bool get isClaimed => status == 'claimed';
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
}

// Embedded sub-object returned by GET /api/in-kind/:id for the beneficiary
class _MyRequest {
  final int id;
  final String status; // pending | approved | rejected
  final String? message;

  _MyRequest({required this.id, required this.status, this.message});

  factory _MyRequest.fromJson(Map<String, dynamic> j) => _MyRequest(
        id: _intVal(j['id']),
        status: j['status']?.toString() ?? 'pending',
        message: _nullStr(j['message']),
      );
}

// Represents a row from GET /api/in-kind/my/:id/requests
class InKindRequest {
  final int id;
  final int donationId;
  final int beneficiaryId;
  final String beneficiaryName;
  final String? beneficiaryEmail;
  final String? beneficiaryPhone;
  final String? beneficiaryLocation;
  final String? message;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  InKindRequest({
    required this.id,
    required this.donationId,
    required this.beneficiaryId,
    required this.beneficiaryName,
    this.beneficiaryEmail,
    this.beneficiaryPhone,
    this.beneficiaryLocation,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory InKindRequest.fromJson(Map<String, dynamic> j) => InKindRequest(
        id: _intVal(j['id']),
        donationId: _intVal(j['donation_id']),
        beneficiaryId: _intVal(j['beneficiary_id']),
        beneficiaryName: j['beneficiary_name']?.toString() ?? '',
        beneficiaryEmail: _nullStr(j['beneficiary_email']),
        beneficiaryPhone: _nullStr(j['beneficiary_phone']),
        beneficiaryLocation: _nullStr(j['beneficiary_location']),
        message: _nullStr(j['message']),
        status: j['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
}

// ── helpers ──────────────────────────────────────────────────────────────────

int _intVal(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

String? _nullStr(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
