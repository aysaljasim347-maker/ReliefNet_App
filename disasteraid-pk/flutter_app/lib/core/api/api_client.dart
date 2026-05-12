import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? requestId;

  ApiException(this.message, {this.statusCode, this.requestId});

  @override
  String toString() => message;
}

class ApiClient {
  // ── Singleton ──────────────────────────────────────────────
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  /// Use ApiClient.instance.get(...) / .post(...) etc. anywhere in the app.
  static ApiClient get instance => _instance;

  // ── State ──────────────────────────────────────────────────
  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  final Map<String, _CacheEntry> _getCache = {};

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  Future<void> Function()? onUnauthorized;

  // ── Constructor ────────────────────────────────────────────
  ApiClient._internal() {
    String defaultUrl;

    if (kIsWeb) {
      defaultUrl = 'http://localhost:3000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      defaultUrl = 'http://10.109.20.48:3000/api';
    } else {
      defaultUrl = 'http://localhost:3000/api';
    }

    dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? defaultUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (options.method.toUpperCase() == 'GET') {
          final key = _cacheKey(options);
          final cached = _getCache[key];
          if (cached != null &&
              DateTime.now().difference(cached.storedAt).inSeconds < 60) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: cached.data,
                statusCode: 200,
                extra: {'fromCache': true},
              ),
            );
          }
        } else {
          _getCache.clear();
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map && data.containsKey('success')) {
          if (data['success'] == true) {
            response.data = data['data'];
          } else {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: data['error'] ?? 'Unknown error',
              ),
            );
          }
        }
        if (response.requestOptions.method.toUpperCase() == 'GET' &&
            response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          _getCache[_cacheKey(response.requestOptions)] =
              _CacheEntry(response.data);
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final response = error.response;
        String message = _messageFor(error);
        String? requestId;

        if (response?.data is Map) {
          final data = response!.data;
          message = _friendlyServerMessage(
            response.statusCode,
            data['error']?.toString() ?? data['message']?.toString(),
          );
          requestId = data['requestId']?.toString();
        }

        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'token');
          _currentUser = null;
          await onUnauthorized?.call();
        }

        final apiError = ApiException(
          message,
          statusCode: response?.statusCode,
          requestId: requestId,
        );

        return handler.next(DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: apiError,
        ));
      },
    ));
  }

  // ── Helpers ────────────────────────────────────────────────

  void setCurrentUser(Map<String, dynamic> user) => _currentUser = user;
  void clearCurrentUser() => _currentUser = null;

  static String messageFromError(Object error,
      [String fallback = 'Request failed']) {
    if (error is ApiException) return error.message;
    if (error is DioException) {
      final apiError = error.error;
      if (apiError is ApiException) return apiError.message;
      return _messageFor(error, fallback);
    }
    final text = error.toString();
    if (text.startsWith('DioException') || text.contains('SocketException')) {
      return 'Check connection';
    }
    return text.isEmpty ? fallback : text;
  }

  static String _messageFor(DioException error,
      [String fallback = 'Request failed']) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'Check connection';
      case DioExceptionType.badResponse:
        return _friendlyServerMessage(error.response?.statusCode, null);
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.badCertificate:
        return 'Check connection';
    }
  }

  static String _friendlyServerMessage(int? statusCode, String? serverMessage) {
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode != null && statusCode >= 500) return 'Server error';
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      return serverMessage.trim();
    }
    return 'Request failed';
  }

  String _cacheKey(RequestOptions options) {
    final query = options.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final queryString = query.map((e) => '${e.key}=${e.value}').join('&');
    final token = options.headers['Authorization']?.toString() ?? '';
    return '${options.method}:${options.uri.path}?$queryString:$token';
  }

  // ── Dio pass-through (so callers can do ApiClient.instance.get(...)) ──

  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters, Options? options}) =>
      dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(String path, {dynamic data, Options? options}) =>
      dio.post<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) =>
      dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options}) =>
      dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(String path, {Options? options}) =>
      dio.delete<T>(path, options: options);
}

class _CacheEntry {
  final dynamic data;
  final DateTime storedAt = DateTime.now();
  _CacheEntry(this.data);
}
