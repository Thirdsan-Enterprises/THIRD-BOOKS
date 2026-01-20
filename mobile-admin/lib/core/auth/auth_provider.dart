import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

// Auth State
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? tenant;

  AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.errorMessage,
    this.user,
    this.tenant,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? user,
    Map<String, dynamic>? tenant,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
      tenant: tenant ?? this.tenant,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthNotifier({
    required ApiClient apiClient,
    required FlutterSecureStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage,
        super(AuthState(isAuthenticated: false, isLoading: false)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: 'auth_token');

    if (token != null) {
      try {
        final userData = await _apiClient.getCurrentUser();
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: userData['user'] as Map<String, dynamic>?,
          tenant: userData['tenant'] as Map<String, dynamic>?,
        );
      } catch (e) {
        // Token invalid, clear it
        await logout();
      }
    }
  }

  Future<bool> login(String email, String password, String domain) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiClient.login(email, password, domain);

      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;
      final tenant = response['tenant'] as Map<String, dynamic>;

      // Store credentials
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'tenant_id', value: tenant['id'] as String);
      await _storage.write(key: 'user_email', value: email);

      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: user,
        tenant: tenant,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (e) {
      // Ignore logout errors
    }

    // Clear stored credentials
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'tenant_id');
    await _storage.delete(key: 'device_id');

    state = AuthState(isAuthenticated: false, isLoading: false);
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);

  return AuthNotifier(
    apiClient: apiClient,
    storage: storage,
  );
});
