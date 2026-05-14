import 'package:disasteraid_pk/core/services/socket_service.dart'; // FIXED TYPO
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import 'package:dio/dio.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _api = ApiClient();

  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _api.onUnauthorized = logout;
  }

  Future<void> checkAuth() async {
    _token = await _storage.read(key: 'token');
    if (_token != null) {
      try {
        final res = await _api.dio.get('/auth/me');
        final data = res.data;
        if (data is Map) {
          _user = Map<String, dynamic>.from(data);
          _api.setCurrentUser(_user!);
          _isAuthenticated = true;
        } else {
          throw Exception('Invalid user data');
        }
      } on DioException {
        await _storage.delete(key: 'token');
        _api.clearCurrentUser();
        _isAuthenticated = false;
        _user = null;
      } catch (e) {
        _isAuthenticated = false;
        _user = null;
      }
    }
    notifyListeners();
  }

  Future<void> register({
    required String name,
    String? email,
    String? phone,
    required String password,
    required String role,
  }) async {
    try {
      final res = await _api.dio.post('/auth/register', data: {
        'name': name,
        'email': email?.isEmpty == true ? null : email,
        'phone': phone?.isEmpty == true ? null : phone,
        'password': password,
        'role': role,
      });

      final data = res.data; // Already unwrapped
      if (data is Map) {
        _token = data['token']?.toString();
        _user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
        _isAuthenticated = true;
        _api.setCurrentUser(_user!);
        await _storage.write(key: 'token', value: _token);
        notifyListeners();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ApiClient.messageFromError(e, 'Email or phone already exists');
      }
      throw ApiClient.messageFromError(e, 'Registration failed');
    }
  }

  Future<void> login(String emailOrPhone, String password) async {
    try {
      final res = await _api.dio.post('/auth/login', data: {
        'email': emailOrPhone, 
        'password': password
      });
      
      final data = res.data; // Already unwrapped
      if (data is Map) {
        _token = data['token']?.toString();
        _user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
        _isAuthenticated = true;
        _api.setCurrentUser(_user!);
        await _storage.write(key: 'token', value: _token);
        notifyListeners();
      }
    } on DioException catch (e) {
      throw ApiClient.messageFromError(e, 'Invalid credentials');
    }
  }

  Future<void> logout() async {
    SocketService().disconnect();
    await _storage.delete(key: 'token');
    _api.clearCurrentUser();
    _isAuthenticated = false;
    _user = null;
    _token = null;
    notifyListeners();
  }
}
