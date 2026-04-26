import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'init_service.dart';
import '../database/app_database.dart';

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

// Offline mode provider - true when using an offline session token
final isOfflineModeProvider = Provider<bool>((ref) {
  final token = ref.watch(authStateProvider).token;
  return token != null && token.startsWith('offline-session-');
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
        // Restore auth token and tenant on the API client (e.g. after app restart)
        if (token != null) {
          _authService.restoreApiClientSession(user);
        }
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

  Future<bool> login(String email, String password, {bool rememberMe = true}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.login(email, password, rememberMe: rememberMe);
      state = AuthState(
        isAuthenticated: true,
        user: result['user'],
        token: result['token'],
      );

      // Run initialization if needed (background task)
      _runInitializationIfNeeded();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }


  /// Run MagicBet initialization if this is the first login
  Future<void> _runInitializationIfNeeded() async {
    try {
      final db = AppDatabase();
      await InitializationService.checkAndRunSetup(db);
    } catch (e) {
      print('Initialization check failed: $e');
      // Don't throw - initialization is a background task
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
  static const _credentialHashKey = 'offline_credential_hash';

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
  Future<Map<String, dynamic>> login(String email, String password, {bool rememberMe = true}) async {
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

        // Remember Me: 30 days. Otherwise session ends after 24 hours.
        final expiry = DateTime.now().add(
          rememberMe ? const Duration(days: 30) : const Duration(hours: 24),
        );
        await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

        // Cache a credential hash so offline logins can verify the password
        // without storing the plaintext or the server token.
        await _storage.write(
          key: _credentialHashKey,
          value: _hashCredential(email, password),
        );

        // Update API client with token and tenant
        _apiClient.setAuthToken(token);
        final user = User.fromJson(userData);
        if (user.tenantId != null) {
          _apiClient.setTenantId(user.tenantId);
        }

        return {
          'token': token,
          'user': user,
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

      // Connection failed — try offline login with cached credentials
      return _tryOfflineLogin(email, password);
    } catch (e) {
      // Any other error — try offline login with cached credentials
      return _tryOfflineLogin(email, password);
    }
  }

  // Offline login: verifies the entered password against the hash stored
  // during the last successful online login, then reuses the real cached
  // user object (with the correct tenant UUID and user ID).
  // Requires at least one prior successful online login on this device.
  Future<Map<String, dynamic>> _tryOfflineLogin(String email, String password) async {
    final storedHash = await _storage.read(key: _credentialHashKey);
    final cachedUserJson = await _storage.read(key: _userKey);

    if (storedHash == null || cachedUserJson == null) {
      throw Exception(
        'No internet connection.\n'
        'Please connect to the internet to log in for the first time.',
      );
    }

    if (_hashCredential(email, password) != storedHash) {
      throw Exception('Invalid email or password');
    }

    final userData = jsonDecode(cachedUserJson) as Map<String, dynamic>;
    final cachedEmail = userData['email'] as String?;
    if (cachedEmail?.toLowerCase() != email.toLowerCase()) {
      throw Exception('Invalid email or password');
    }

    // Issue a device-local offline token (not a Sanctum token).
    // It is never sent to the server; real API calls will be retried
    // once connectivity is restored using the refreshed Sanctum token.
    final offlineToken = 'offline-session-${DateTime.now().millisecondsSinceEpoch}';

    await _storage.write(key: _tokenKey, value: offlineToken);
    // Extend offline expiry by 7 days from now
    final expiry = DateTime.now().add(const Duration(days: 7));
    await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

    final user = User.fromJson(userData);
    if (user.tenantId != null) {
      _apiClient.setTenantId(user.tenantId);
    }

    return {
      'token': offlineToken,
      'user': user,
    };
  }

  // HMAC-SHA256 of the password keyed on the email address.
  // Not bcrypt, but the secret stays in the OS keychain (flutter_secure_storage)
  // so casual access is prevented without needing a full KDF.
  String _hashCredential(String email, String password) {
    final key = utf8.encode(email.toLowerCase());
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(password)).toString();
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

        // Update API client with token and tenant
        _apiClient.setAuthToken(token);
        final user = User.fromJson(userData);
        if (user.tenantId != null) {
          _apiClient.setTenantId(user.tenantId);
        }

        return {
          'token': token,
          'user': user,
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

  /// Re-applies auth token and tenant ID to the API client.
  /// Called after app restart when a stored session is found.
  Future<void> restoreApiClientSession(User? user) async {
    final token = await getToken();
    if (token != null) {
      _apiClient.setAuthToken(token);
    }
    if (user?.tenantId != null) {
      _apiClient.setTenantId(user!.tenantId);
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
    await _storage.delete(key: _credentialHashKey);

    // Clear API client token and tenant
    _apiClient.clearAuthToken();
    _apiClient.clearTenantId();
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
