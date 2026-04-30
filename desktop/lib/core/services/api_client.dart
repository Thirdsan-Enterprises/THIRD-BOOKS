import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';

// API Configuration
class ApiConfig {
  // Production API URL
  static const String productionUrl = 'https://api.thirdbooks.digital';

  // Development API URL (for local testing)
  static const String developmentUrl = 'http://localhost:8000';

  // Current environment
  static const bool isProduction = true;

  // Get current base URL
  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  // API version
  static const String apiVersion = '/api';

  // Full API URL
  static String get apiUrl => '$baseUrl$apiVersion';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// API Client
class ApiClient {
  late final Dio _dio;
  final Logger _logger = Logger();
  String? _authToken;
  String? _tenantId;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_buildInterceptor());
  }

  Interceptor _buildInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token if available
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        // Add tenant identifier so backend tenant middleware can resolve the DB
        if (_tenantId != null) {
          options.headers['X-Tenant-ID'] = _tenantId;
        }

        _logger.d('API Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('API Response: ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('API Error: ${error.message}', error: error);

        // Handle 401 Unauthorized
        if (error.response?.statusCode == 401) {
          // Token expired or invalid
          clearAuthToken();
        }

        return handler.next(error);
      },
    );
  }

  // Set auth token
  void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear auth token
  void clearAuthToken() {
    _authToken = null;
  }

  // Set tenant ID (injected into X-Tenant-ID header for every request)
  void setTenantId(String? tenantId) {
    _tenantId = tenantId;
  }

  // Clear tenant ID
  void clearTenantId() {
    _tenantId = null;
  }

  // Check if has auth token
  bool get hasAuthToken => _authToken != null;

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Handle errors
  DioException _handleError(DioException error) {
    String message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Send timeout. Please try again.';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timeout. Please try again.';
        break;
      case DioExceptionType.badResponse:
        message = _getErrorMessage(error.response);
        break;
      case DioExceptionType.connectionError:
        message = 'Connection error. Please check your internet connection.';
        break;
      default:
        message = 'An unexpected error occurred. Please try again.';
    }

    return DioException(
      requestOptions: error.requestOptions,
      error: message,
      response: error.response,
      type: error.type,
    );
  }

  String _getErrorMessage(Response? response) {
    if (response == null) {
      return 'Server error. Please try again.';
    }

    switch (response.statusCode) {
      case 400:
        return response.data['message'] ?? 'Bad request.';
      case 401:
        return 'Unauthorized. Please login again.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 422:
        final errors = response.data['errors'];
        if (errors != null && errors is Map) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            return firstError.first.toString();
          }
        }
        return response.data['message'] ?? 'Validation error.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return response.data['message'] ?? 'An error occurred.';
    }
  }

  // Check API health
  Future<bool> checkHealth() async {
    try {
      final response = await get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Attachments ────────────────────────────────────────────────────────────

  /// Upload one or more local files as attachments to a record.
  /// Returns the list of [_UploadedAttachment] objects created on the server.
  Future<List<_UploadedAttachment>> uploadAttachments(
    String attachableType,
    int attachableId,
    List<PlatformFile> files, {
    List<String?>? labels,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('attachable_type', attachableType));
    formData.fields.add(MapEntry('attachable_id', attachableId.toString()));

    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      if (f.bytes != null) {
        formData.files.add(MapEntry(
          'files[]',
          MultipartFile.fromBytes(f.bytes!, filename: f.name),
        ));
      } else if (f.path != null) {
        formData.files.add(MapEntry(
          'files[]',
          MultipartFile.fromBytes([], filename: f.name),
        ));
      } else {
        continue;
      }
      final label = labels != null && i < labels.length ? labels[i] : null;
      if (label != null) {
        formData.fields.add(MapEntry('labels[$i]', label));
      }
    }

    try {
      final resp = await _dio.post(
        '/attachments',
        data: formData,
        options: Options(
          headers: {
            if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            if (_tenantId != null) 'X-Tenant-ID': _tenantId!,
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      final list = (resp.data['attachments'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      return list.map(_UploadedAttachment.fromJson).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Outlets ───────────────────────────────────────────────────────────────

  /// Fetch all outlets from the server.
  Future<List<Map<String, dynamic>>> getOutlets({String? region}) async {
    final resp = await get('/outlets', queryParameters: {
      if (region != null && region != 'All') 'region': region,
    });
    final list = (resp.data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  /// Seed default outlets on the server (idempotent).
  Future<Map<String, dynamic>> seedOutlets() async {
    final resp = await post('/outlets/seed', data: {});
    return resp.data as Map<String, dynamic>;
  }

  /// Create a new outlet.
  Future<Map<String, dynamic>> createOutlet(Map<String, dynamic> data) async {
    final resp = await post('/outlets', data: data);
    return (resp.data['data'] as Map<String, dynamic>? ?? resp.data as Map<String, dynamic>? ?? {});
  }

  /// Update an existing outlet.
  Future<Map<String, dynamic>> updateOutlet(
      String id, Map<String, dynamic> data) async {
    final resp = await put('/outlets/$id', data: data);
    return (resp.data['data'] as Map<String, dynamic>? ?? resp.data as Map<String, dynamic>? ?? {});
  }

  /// Delete an outlet permanently.
  Future<void> deleteOutlet(String id) async {
    await delete('/outlets/$id');
  }

  // ── Outlet Revenues ───────────────────────────────────────────────────────

  /// POST outlet revenue rows parsed from a CSV file.
  /// Each row must have: outlet_code, date, stake_amount, payout_amount, net_amount.
  /// Returns {created, skipped, errors}.
  Future<Map<String, dynamic>> postOutletRevenues(
      List<Map<String, dynamic>> rows) async {
    try {
      final resp = await post('/outlet-revenues', data: rows);
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Banking — Statements ──────────────────────────────────────────────────

  /// Fetch all uploaded bank statements for the company.
  Future<List<Map<String, dynamic>>> getBankStatements({
    int? bankAccountId,
    String? status,
  }) async {
    final resp = await get('/banking/statements', queryParameters: {
      if (bankAccountId != null) 'bank_account_id': bankAccountId,
      if (status != null) 'status': status,
      'per_page': 50,
    });
    final raw = resp.data['data'] as List? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  /// Upload a new bank statement (CSV file or JSON rows).
  Future<Map<String, dynamic>> uploadBankStatement({
    required String bankAccountId,
    required String fromDate,
    required String toDate,
    String? referenceNumber,
    String? notes,
    double? openingBalance,
    double? closingBalance,
    String? csvFilePath,
    List<Map<String, dynamic>>? rows,
  }) async {
    final formData = FormData();
    formData.fields.addAll([
      MapEntry('bank_account_id', bankAccountId),
      MapEntry('from_date', fromDate),
      MapEntry('to_date', toDate),
      if (referenceNumber != null) MapEntry('reference_number', referenceNumber),
      if (notes != null) MapEntry('notes', notes),
      if (openingBalance != null) MapEntry('opening_balance', openingBalance.toString()),
      if (closingBalance != null) MapEntry('closing_balance', closingBalance.toString()),
    ]);

    // csvFilePath is ignored on web — pass rows as JSON instead

    try {
      final resp = await _dio.post(
        '/banking/statements',
        data: formData,
        options: Options(
          headers: {
            if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            if (_tenantId != null) 'X-Tenant-ID': _tenantId!,
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return resp.data['statement'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete an uploaded bank statement.
  Future<void> deleteBankStatement(int statementId) async {
    await delete('/banking/statements/$statementId');
  }

  /// Fetch a single statement with all its lines.
  Future<Map<String, dynamic>> getBankStatement(int statementId) async {
    final resp = await get('/banking/statements/$statementId');
    return resp.data['statement'] as Map<String, dynamic>? ?? {};
  }

  // ── Banking — Reconciliation ──────────────────────────────────────────────

  /// Return ALL chart of accounts (all types: assets, liabilities, loans, etc.)
  /// for the CoA picker in bank reconciliation.
  Future<List<Map<String, dynamic>>> getReconciliationAccounts({String? search}) async {
    final resp = await get('/banking/reconciliation/accounts', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (resp.data['accounts'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Return open bills and/or invoices available to reconcile against.
  Future<List<Map<String, dynamic>>> getReconciliationItems({String? type}) async {
    final resp = await get('/banking/reconciliation/items', queryParameters: {
      if (type != null) 'type': type,
    });
    return (resp.data['items'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Reconcile one statement line against multiple bills/invoices.
  Future<Map<String, dynamic>> reconcileStatementLine({
    required int statementId,
    required int lineId,
    required int bankAccountId,
    required List<Map<String, dynamic>> items,
    // items: [{'type': 'bill', 'id': 12, 'amount': 500000}, ...]
  }) async {
    final resp = await post(
      '/banking/statements/$statementId/lines/$lineId/reconcile',
      data: {
        'bank_account_id': bankAccountId,
        'items': items,
      },
    );
    return resp.data as Map<String, dynamic>? ?? {};
  }

  /// Reverse (undo) a reconciliation item.
  Future<void> unreconcileItem(int itemId) async {
    await delete('/banking/reconciliation-items/$itemId');
  }

  // ── Asset Register ────────────────────────────────────────────────────────

  /// Fetch all assets (optionally filtered by status or category).
  Future<List<Map<String, dynamic>>> getAssets({
    String? status,
    String? category,
    int? coaAccountId,
  }) async {
    final resp = await get('/assets', queryParameters: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (coaAccountId != null) 'coa_account_id': coaAccountId,
      'per_page': 100,
    });
    final raw = resp.data['data'] as List? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  /// Fetch a single asset with its depreciation history.
  Future<Map<String, dynamic>> getAsset(int assetId) async {
    final resp = await get('/assets/$assetId');
    return resp.data['asset'] as Map<String, dynamic>? ?? {};
  }

  /// Create a new asset record manually.
  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> data) async {
    final resp = await post('/assets', data: data);
    return resp.data['asset'] as Map<String, dynamic>? ?? {};
  }

  /// Update asset details (name, depreciation settings, etc.).
  Future<Map<String, dynamic>> updateAsset(
      int assetId, Map<String, dynamic> data) async {
    final resp = await put('/assets/$assetId', data: data);
    return resp.data['asset'] as Map<String, dynamic>? ?? {};
  }

  /// Mark asset as disposed and generate disposal journal entry.
  Future<Map<String, dynamic>> disposeAsset(
    int assetId, {
    required String disposalDate,
    double? proceeds,
    int? proceedsAccountId,
    String? notes,
  }) async {
    final resp = await post('/assets/$assetId/dispose', data: {
      'disposal_date': disposalDate,
      if (proceeds != null) 'proceeds': proceeds,
      if (proceedsAccountId != null) 'proceeds_account_id': proceedsAccountId,
      if (notes != null) 'notes': notes,
    });
    return resp.data as Map<String, dynamic>? ?? {};
  }

  /// Post one depreciation period for an asset.
  Future<Map<String, dynamic>> postAssetDepreciation(
    int assetId, {
    required String periodDate,
    required int depreciationAccountId,
    required int accumulatedDeprAccountId,
  }) async {
    final resp = await post('/assets/$assetId/depreciate', data: {
      'period_date': periodDate,
      'depreciation_account_id': depreciationAccountId,
      'accumulated_depr_account_id': accumulatedDeprAccountId,
    });
    return resp.data as Map<String, dynamic>? ?? {};
  }

  /// Get the full depreciation schedule preview for an asset.
  Future<Map<String, dynamic>> getAssetDepreciationSchedule(int assetId) async {
    final resp = await get('/assets/$assetId/depreciation-schedule');
    return resp.data as Map<String, dynamic>? ?? {};
  }

  // ── User Management (tenant-scoped) ─────────────────────────────────────────

  /// List all users belonging to the current tenant.
  Future<List<Map<String, dynamic>>> listUsers() async {
    try {
      final resp = await get('/users');
      return (resp.data['users'] as List? ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new user in the current tenant.
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final resp = await post('/users', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });
      return resp.data['user'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update a user's role or active status.
  Future<Map<String, dynamic>> updateUser(
    int userId, {
    String? role,
    bool? isActive,
    String? name,
  }) async {
    try {
      final resp = await put('/users/$userId', data: {
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
      });
      return resp.data['user'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Remove a user from the current tenant.
  Future<void> deleteUser(int userId) async {
    await delete('/users/$userId');
  }

  // ── Invoice Payments ───────────────────────────────────────────────────────

  /// Record a payment against an invoice.
  Future<Map<String, dynamic>> recordInvoicePayment(
    String invoiceId, {
    required double amount,
    required String paymentDate,
    String? paymentMethod,
    String? reference,
  }) async {
    try {
      final resp = await post('/invoices/$invoiceId/payment', data: {
        'amount': amount,
        'payment_date': paymentDate,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (reference != null) 'reference': reference,
      });
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Bill Payments ─────────────────────────────────────────────────────────

  /// Record a payment against a bill.
  Future<Map<String, dynamic>> recordBillPayment(
    String billId, {
    required double amount,
    required String paymentDate,
    String? paymentMethod,
    String? reference,
  }) async {
    try {
      final resp = await post('/bills/$billId/payment', data: {
        'amount': amount,
        'payment_date': paymentDate,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (reference != null) 'reference': reference,
      });
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Customer / Vendor Statements ──────────────────────────────────────────

  /// Fetch aged receivables report from the server.
  Future<Map<String, dynamic>> getAgedReceivables() async {
    try {
      final resp = await get('/reports/aged-receivables');
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch aged payables report from the server.
  Future<Map<String, dynamic>> getAgedPayables() async {
    try {
      final resp = await get('/reports/aged-payables');
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch statement for a specific customer.
  Future<Map<String, dynamic>> getCustomerStatement(String customerId) async {
    try {
      final resp = await get('/customers/$customerId/statement');
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch statement for a specific vendor.
  Future<Map<String, dynamic>> getVendorStatement(String vendorId) async {
    try {
      final resp = await get('/vendors/$vendorId/statement');
      return resp.data as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Server attachment response model — used only by ApiClient.uploadAttachments.
// Kept here so the widget layer has no dependency on server-specific types.
// ---------------------------------------------------------------------------
class _UploadedAttachment {
  final int id;
  final String fileName;
  final String? label;
  final int? fileSize;
  final String? url;
  final String? mimeType;
  final String uploadedAt;

  const _UploadedAttachment({
    required this.id,
    required this.fileName,
    this.label,
    this.fileSize,
    this.url,
    this.mimeType,
    required this.uploadedAt,
  });

  factory _UploadedAttachment.fromJson(Map<String, dynamic> j) =>
      _UploadedAttachment(
        id: j['id'] as int,
        fileName: j['file_name'] as String,
        label: j['label'] as String?,
        fileSize: j['file_size'] as int?,
        url: j['url'] as String?,
        mimeType: j['mime_type'] as String?,
        uploadedAt: j['created_at'] as String? ?? '',
      );
}
