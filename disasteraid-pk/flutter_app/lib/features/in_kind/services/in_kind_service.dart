import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/in_kind_donation.dart';

class InKindService {
  final _api = ApiClient();

  // ── Beneficiary ────────────────────────────────────────────────────────────

  /// Browse all available donations (beneficiary)
  Future<List<InKindDonation>> getAvailableDonations() async {
    try {
      final res = await _api.dio.get('/in-kind');
      final rows = res.data is List ? res.data as List : const [];
      return rows
          .map((e) =>
              InKindDonation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to load donations');
    }
  }

  /// Get single donation detail — includes myRequest for the beneficiary
  Future<InKindDonation> getDonationDetail(int id) async {
    try {
      final res = await _api.dio.get('/in-kind/$id');
      return InKindDonation.fromJson(
          Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to load donation');
    }
  }

  /// Send a request for a donation (beneficiary)
  Future<void> requestDonation(int donationId, {String? message}) async {
    try {
      await _api.dio.post(
        '/in-kind/$donationId/request',
        data: {'message': message ?? ''},
      );
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to send request');
    }
  }

  // ── Donor ──────────────────────────────────────────────────────────────────

  /// Donor's own donations list
  Future<List<InKindDonation>> getMyDonations() async {
    try {
      final res = await _api.dio.get('/in-kind/my');
      final rows = res.data is List ? res.data as List : const [];
      return rows
          .map((e) =>
              InKindDonation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to load your donations');
    }
  }

  /// All requests on one of the donor's donations
  Future<List<InKindRequest>> getRequestsForDonation(int donationId) async {
    try {
      final res = await _api.dio.get('/in-kind/my/$donationId/requests');
      final rows = res.data is List ? res.data as List : const [];
      return rows
          .map((e) =>
              InKindRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to load requests');
    }
  }

  /// Approve a request (donor)
  /// Flutter uploads image to Cloudinary first, gets back imageUrl,
  /// then calls createDonation with that URL — no multipart to our backend.
  Future<void> approveRequest({
    required int donationId,
    required int requestId,
  }) async {
    try {
      await _api.dio.post(
        '/in-kind/my/$donationId/requests/$requestId/approve',
      );
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to approve request');
    }
  }

  /// Create a new in-kind donation.
  /// imageUrl must already be a Cloudinary URL — upload to Cloudinary first,
  /// then pass the URL here as plain JSON.
  Future<InKindDonation> createDonation({
    required String title,
    String? description,
    required String imageUrl, // Cloudinary URL
    required String location,
    double? latitude,
    double? longitude,
    String? expiresAt, // ISO-8601 string or null
  }) async {
    try {
      final res = await _api.dio.post('/in-kind', data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'image_url': imageUrl,
        'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (expiresAt != null) 'expires_at': expiresAt,
      });
      return InKindDonation.fromJson(
          Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to create donation');
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  /// Admin: full record of all in-kind donations
  Future<List<InKindDonation>> adminGetAll() async {
    try {
      final res = await _api.dio.get('/in-kind/admin/all');
      final rows = res.data is List ? res.data as List : const [];
      return rows
          .map((e) =>
              InKindDonation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException('Failed to load admin records');
    }
  }
}
