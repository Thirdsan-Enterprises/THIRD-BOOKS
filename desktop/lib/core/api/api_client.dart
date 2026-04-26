import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  String? _authToken;
  String? _tenantId;

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setAuthToken(String token) {
    _authToken = token;
  }

  void setTenantId(String tenantId) {
    _tenantId = tenantId;
  }

  void clearAuth() {
    _authToken = null;
    _tenantId = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_tenantId != null) {
      headers['X-Tenant-ID'] = _tenantId!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      body['message'] as String? ?? 'Unknown error',
      statusCode: response.statusCode,
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  // Auth endpoints
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String companyName,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'company_name': companyName,
      }),
    );
    return _handleResponse(response);
  }

  Future<void> logout() async {
    await _client.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: _headers,
    );
    clearAuth();
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/auth/profile'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  // Sync endpoints
  Future<Map<String, dynamic>> sync({
    required String deviceId,
    required int afterSequence,
    required List<Map<String, dynamic>> events,
    String deviceName = 'Desktop',
    String deviceType = 'desktop',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/sync'),
      headers: _headers,
      body: jsonEncode({
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'after_sequence': afterSequence,
        'events': events,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> pullEvents({
    required String deviceId,
    required int afterSequence,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/sync/pull?device_id=${Uri.encodeComponent(deviceId)}&after_sequence=$afterSequence'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  // Accounts endpoints
  Future<List<dynamic>> getAccounts() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/accounts'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/accounts'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateAccount(String id, Map<String, dynamic> data) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/accounts/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Customers endpoints
  Future<List<dynamic>> getCustomers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/customers'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/customers'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Vendors endpoints
  Future<List<dynamic>> getVendors() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/vendors'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createVendor(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/vendors'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Invoices endpoints
  Future<List<dynamic>> getInvoices() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/invoices'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/invoices'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Bills endpoints
  Future<List<dynamic>> getBills() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/bills'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/bills'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Journal entries endpoints
  Future<List<dynamic>> getJournalEntries() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/journal-entries'),
      headers: _headers,
    );
    final body = await _handleResponse(response);
    return body['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createJournalEntry(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/journal-entries'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  // Reports endpoints
  Future<Map<String, dynamic>> getTrialBalance({DateTime? asOf}) async {
    var url = '$baseUrl/reports/trial-balance';
    if (asOf != null) {
      url += '?as_of=${asOf.toIso8601String().split('T')[0]}';
    }
    final response = await _client.get(Uri.parse(url), headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/reports/income-statement'
          '?start_date=${startDate.toIso8601String().split('T')[0]}'
          '&end_date=${endDate.toIso8601String().split('T')[0]}'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getBalanceSheet({DateTime? asOf}) async {
    var url = '$baseUrl/reports/balance-sheet';
    if (asOf != null) {
      url += '?as_of=${asOf.toIso8601String().split('T')[0]}';
    }
    final response = await _client.get(Uri.parse(url), headers: _headers);
    return _handleResponse(response);
  }
}
