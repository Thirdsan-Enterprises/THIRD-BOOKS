import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// API Configuration
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

// Secure Storage Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add request interceptor for auth token
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final storage = ref.read(secureStorageProvider);
        final token = await storage.read(key: 'auth_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Add tenant header if available
        final tenantId = await storage.read(key: 'tenant_id');
        if (tenantId != null) {
          options.headers['X-Tenant'] = tenantId;
        }

        // Add device ID for sync
        final deviceId = await storage.read(key: 'device_id');
        if (deviceId != null) {
          options.headers['X-Device-ID'] = deviceId;
        }

        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired, handle logout
          // This will be implemented in auth provider
        }
        return handler.next(error);
      },
    ),
  );

  // Add logger in debug mode
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      compact: true,
    ),
  );

  return dio;
});

// API Client Service
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // Auth endpoints
  Future<Map<String, dynamic>> login(String email, String password, String domain) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'domain': domain,
    });
    return response.data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get('/auth/user');
    return response.data;
  }

  // Dashboard endpoints
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/dashboard/stats');
    return response.data;
  }

  // Sync endpoints
  Future<Map<String, dynamic>> syncEvents({
    required String deviceId,
    String? deviceName,
    String? deviceType,
    int? afterSequence,
    List<Map<String, dynamic>>? events,
    String? resolutionStrategy,
  }) async {
    final response = await _dio.post('/sync', data: {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType ?? 'mobile',
      'after_sequence': afterSequence,
      'events': events,
      'resolution_strategy': resolutionStrategy ?? 'server_wins',
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getSyncStatus(String deviceId) async {
    final response = await _dio.get('/sync/status', queryParameters: {
      'device_id': deviceId,
    });
    return response.data;
  }

  // Conflict endpoints
  Future<Map<String, dynamic>> getConflicts({
    String? status,
    String? aggregateType,
    int page = 1,
  }) async {
    final response = await _dio.get('/conflicts', queryParameters: {
      if (status != null) 'status': status,
      if (aggregateType != null) 'aggregate_type': aggregateType,
      'page': page,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getConflictStatistics() async {
    final response = await _dio.get('/conflicts/statistics');
    return response.data;
  }

  Future<void> resolveConflict(String conflictId, String strategy) async {
    await _dio.post('/conflicts/$conflictId/resolve/$strategy');
  }

  // Invoice endpoints
  Future<Map<String, dynamic>> getInvoices({
    String? status,
    int page = 1,
  }) async {
    final response = await _dio.get('/invoices', queryParameters: {
      if (status != null) 'status': status,
      'page': page,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final response = await _dio.get('/invoices/$id');
    return response.data;
  }

  // Bill endpoints
  Future<Map<String, dynamic>> getBills({
    String? status,
    int page = 1,
  }) async {
    final response = await _dio.get('/bills', queryParameters: {
      if (status != null) 'status': status,
      'page': page,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getBill(String id) async {
    final response = await _dio.get('/bills/$id');
    return response.data;
  }

  // Reports endpoints
  Future<Map<String, dynamic>> generateReport(
    String reportType, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _dio.post('/reports/generate', data: {
      'report_type': reportType,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    });
    return response.data;
  }
}

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
