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

  Future<void> checkAuth() async {
    _token = await _storage.read(key: 'token');
    if (_token!= null) {
      try {
        final res = await _api.dio.get('/auth/me');
        _user = res.data['data'];
        _isAuthenticated = true;
      } catch (e) {
        await _storage.delete(key: 'token');
        _isAuthenticated = false;
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
        'email': email?.isEmpty == true? null : email,
        'phone': phone?.isEmpty == true? null : phone,
        'password': password,
        'role': role,
      });
      print('REGISTER RESPONSE: ${res.data}');

      _token = res.data['data']['token'];
      _user = res.data['data']['user'];
      _isAuthenticated = true;
      await _storage.write(key: 'token', value: _token);
      notifyListeners();
    } on DioException catch (e) {
      print('REGISTER ERROR: ${e.response?.data}');
      if (e.response?.statusCode == 409 || e.response?.data['error']?.contains('exists')) {
        throw 'Email or phone already exists';
      }
      throw 'Registration failed: ${e.message}';
    } catch (e) {
      print('REGISTER UNKNOWN ERROR: $e');
      throw 'Registration failed';
    }
  }

  Future<void> login(String emailOrPhone, String password) async {
    try {
      final res = await _api.dio.post('/auth/login', data: {'email': emailOrPhone, 'password': password});
      _token = res.data['data']['token'];
      _user = res.data['data']['user'];
      _isAuthenticated = true;
      await _storage.write(key: 'token', value: _token);
      notifyListeners();
    } on DioException catch (e) {
      throw 'Invalid credentials';
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    _isAuthenticated = false;
    _user = null;
    _token = null;
    notifyListeners();
  }
}
