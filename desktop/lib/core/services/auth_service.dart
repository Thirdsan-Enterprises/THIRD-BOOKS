import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';

// Auth state
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// User model
class User {
  final int id;
  final String? tenantId;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  User({
    required this.id,
    this.tenantId,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isAccountant => role == 'accountant' || isAdmin;
  bool get canPostTransactions => isAccountant || role == 'manager';
}

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

// Auth state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);

    try {
      final isAuthenticated = await _authService.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authService.getCurrentUser();
        final token = await _authService.getToken();
        state = AuthState(
          isAuthenticated: true,
          user: user,
          token: token,
        );
      } else {
        state = const AuthState();
      }
    } catch (e) {
      state = const AuthState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.login(email, password);
      state = AuthState(
        isAuthenticated: true,
        user: result['user'],
        token: result['token'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = const AuthState();
  }

  void setUser(User user) {
    state = state.copyWith(user: user);
  }
}

// Auth service
class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _tokenExpiryKey = 'token_expiry';

  AuthService(this._apiClient);

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return false;

    // Check token expiry
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await logout();
        return false;
      }
    }

    return true;
  }

  // Validate token with API
  Future<bool> validateToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await _apiClient.get(
        '/auth/user',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Update stored user data
        final userData = response.data['data'] ?? response.data;
        await _storage.write(key: _userKey, value: jsonEncode(userData));
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Get stored token
  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  // Get current user from storage
  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token == null || userData == null) {
          throw Exception('Invalid response from server');
        }

        // Store token and user
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(userData));

        // Set token expiry (24 hours from now)
        final expiry = DateTime.now().add(const Duration(hours: 24));
        await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

        // Update API client with token
        _apiClient.setAuthToken(token);

        return {
          'token': token,
          'user': User.fromJson(userData),
        };
      }

      throw Exception(response.data['message'] ?? 'Login failed');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid email or password');
      }
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null) {
          final firstError = (errors as Map).values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError.first);
          }
        }
        throw Exception('Validation error');
      }

      // If connection failed, try demo mode login
      return _tryDemoLogin(email, password);
    } catch (e) {
      // If any other error, try demo mode login
      return _tryDemoLogin(email, password);
    }
  }

  // Demo mode login for offline testing
  Future<Map<String, dynamic>> _tryDemoLogin(String email, String password) async {
    // Check demo credentials
    if (email == 'admin@thirdbooks.digital' && password == 'Admin@123') {
      final demoUser = {
        'id': 1,
        'tenant_id': '1',
        'name': 'Admin User',
        'email': 'admin@thirdbooks.digital',
        'phone': '+256 700 000000',
        'role': 'admin',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      const demoToken = 'demo-token-thirdbooks-2026';

      // Store demo token and user
      await _storage.write(key: _tokenKey, value: demoToken);
      await _storage.write(key: _userKey, value: jsonEncode(demoUser));

      // Set token expiry (24 hours from now)
      final expiry = DateTime.now().add(const Duration(hours: 24));
      await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

      return {
        'token': demoToken,
        'user': User.fromJson(demoUser),
      };
    }

    // Also allow demo/demo for quick testing
    if (email == 'demo@thirdbooks.digital' && password == 'Demo@123') {
      final demoUser = {
        'id': 2,
        'tenant_id': '1',
        'name': 'Demo User',
        'email': 'demo@thirdbooks.digital',
        'phone': '+256 700 111111',
        'role': 'accountant',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      const demoToken = 'demo-token-user-2026';

      await _storage.write(key: _tokenKey, value: demoToken);
      await _storage.write(key: _userKey, value: jsonEncode(demoUser));

      final expiry = DateTime.now().add(const Duration(hours: 24));
      await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

      return {
        'token': demoToken,
        'user': User.fromJson(demoUser),
      };
    }

    throw Exception('Invalid email or password. Use demo credentials:\nadmin@thirdbooks.digital / Admin@123');
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String companyName,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'company_name': companyName,
          'phone': phone,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token == null || userData == null) {
          throw Exception('Invalid response from server');
        }

        // Store token and user
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(userData));

        // Set token expiry
        final expiry = DateTime.now().add(const Duration(hours: 24));
        await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

        // Update API client with token
        _apiClient.setAuthToken(token);

        return {
          'token': token,
          'user': User.fromJson(userData),
        };
      }

      throw Exception(response.data['message'] ?? 'Registration failed');
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null) {
          final firstError = (errors as Map).values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError.first);
          }
        }
      }
      throw Exception('Registration failed. Please try again.');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _apiClient.post(
          '/auth/logout',
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      // Ignore logout API errors
    }

    // Clear stored data
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _tokenExpiryKey);

    // Clear API client token
    _apiClient.clearAuthToken();
  }

  // Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      await _apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to send reset email');
    }
  }
}
